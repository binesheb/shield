use anyhow::Result;
use clap::{Parser, Subcommand};
use std::{path::PathBuf, thread, time::Duration};

use shield::{
    append_log, build_snapshot, read_state, scan_hashes, sha256_file, windows_defender_scan,
    windows_defender_status, windows_defender_threats, windows_defender_update, write_state, VERSION,
};

#[derive(Parser, Debug)]
#[command(
    name = "shield",
    version,
    about = "SHIELD — open-source endpoint security",
    long_about = "SHIELD combines local security telemetry, Windows Defender integration, scanning, monitoring and response controls."
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    #[arg(long, global = true)]
    json: bool,
}

#[derive(Subcommand, Debug)]
enum Commands {
    Status,
    Scan {
        path: PathBuf,
        #[arg(long, help = "Also ask Windows Defender to perform a custom scan")]
        defender: bool,
    },
    DefenderScan {
        #[arg(value_parser = ["quick", "full", "custom"])]
        kind: String,
        #[arg(long)]
        path: Option<PathBuf>,
    },
    DefenderUpdate,
    Threats,
    Engines,
    Doctor,
    Version,
    Ui,
    Service {
        #[command(subcommand)]
        command: ServiceCommand,
    },
}

#[derive(Subcommand, Debug)]
enum ServiceCommand {
    Run,
    Install,
    Uninstall,
}

fn print_status(json: bool) -> Result<()> {
    let state = read_state().unwrap_or_else(|_| build_snapshot(false, None, None));
    if json {
        println!("{}", serde_json::to_string_pretty(&state)?);
    } else {
        println!("SHIELD {VERSION}");
        println!();
        println!("Protection      : {}", if state.protection_enabled { "ACTIVE" } else { "ATTENTION" });
        println!("Service         : {}", if state.service_heartbeat { "RUNNING" } else { "NOT RUNNING" });
        println!("Threats         : {}", state.threat_count);
        if let Some(defender) = state.defender {
            println!("Defender mode   : {}", defender.running_mode.unwrap_or_else(|| "Unknown".into()));
            println!("Engine          : {}", defender.engine_version.unwrap_or_else(|| "Unknown".into()));
            println!("Signatures      : {}", defender.signature_version.unwrap_or_else(|| "Unknown".into()));
        } else {
            println!("Defender        : unavailable");
        }
        println!("Last update     : {}", state.timestamp);
    }
    Ok(())
}

fn run_service() -> Result<()> {
    #[cfg(windows)]
    {
        shield_windows_service::dispatch()
    }
    #[cfg(not(windows))]
    {
        anyhow::bail!("Windows service mode is only available on Windows")
    }
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Status => print_status(cli.json)?,
        Commands::Scan { path, defender } => {
            let (files, errors) = scan_hashes(&path)?;
            if defender {
                windows_defender_scan("custom", Some(&path))?;
            }
            if cli.json {
                println!(
                    r#"{{"target":{},"files":{},"errors":{},"result":"SCANNED"}}"#,
                    serde_json::to_string(path.to_string_lossy().as_ref())?,
                    files,
                    errors
                );
            } else if path.is_file() {
                println!("Target: {}", path.display());
                println!("SHA-256: {}", sha256_file(&path)?);
                println!("Result: SCANNED");
                if defender {
                    println!("Defender: CUSTOM SCAN STARTED");
                }
            } else {
                println!("Target: {}", path.display());
                println!("Files scanned: {files}");
                println!("Errors: {errors}");
                println!("Result: SCANNED");
                if defender {
                    println!("Defender: CUSTOM SCAN STARTED");
                }
            }
        }
        Commands::DefenderScan { kind, path } => {
            if kind == "custom" && path.is_none() {
                anyhow::bail!("--path is required for a custom Defender scan");
            }
            windows_defender_scan(&kind, path.as_deref())?;
            println!("Windows Defender {kind} scan started.");
        }
        Commands::DefenderUpdate => {
            windows_defender_update()?;
            println!("Windows Defender signatures update requested.");
        }
        Commands::Threats => {
            let threats = windows_defender_threats()?;
            if cli.json {
                println!("{}", serde_json::to_string_pretty(&threats)?);
            } else if threats.is_empty() {
                println!("No Windows Defender threat detections reported.");
            } else {
                for threat in threats {
                    println!("- {} ({:?})", threat.name, threat.id);
                    for resource in threat.resources {
                        println!("  {resource}");
                    }
                }
            }
        }
        Commands::Engines => {
            println!("SHIELD engines");
            println!("  SHA-256 scanner       ACTIVE");
            #[cfg(windows)]
            println!("  Microsoft Defender   ACTIVE");
            #[cfg(not(windows))]
            println!("  Microsoft Defender   UNAVAILABLE");
            println!("  YARA                  PLANNED");
            println!("  ClamAV                PLANNED");
        }
        Commands::Doctor => {
            println!("SHIELD Doctor");
            println!("  Core                  OK");
            println!("  State store           {}", if shield::ensure_data_dir().is_ok() { "OK" } else { "FAILED" });
            match windows_defender_status() {
                Ok(status) => {
                    println!("  Defender service       {}", if status.service_enabled == Some(true) { "OK" } else { "ATTENTION" });
                    println!("  Defender real-time    {}", if status.realtime_protection_enabled == Some(true) { "ON" } else { "OFF" });
                    println!("  Defender engine       {}", status.engine_version.unwrap_or_else(|| "Unknown".into()));
                }
                Err(error) => println!("  Defender               UNAVAILABLE ({error})"),
            }
        }
        Commands::Version => println!("{VERSION}"),
        Commands::Ui => {
            let ui = if cfg!(windows) { "shield-ui.exe" } else { "shield-ui" };
            std::process::Command::new(ui).spawn()?;
        }
        Commands::Service { command } => match command {
            ServiceCommand::Run => run_service()?,
            ServiceCommand::Install => {
                #[cfg(windows)]
                shield_windows_service::install_current_executable()?;
                #[cfg(not(windows))]
                anyhow::bail!("Windows service mode is only available on Windows");
            }
            ServiceCommand::Uninstall => {
                #[cfg(windows)]
                shield_windows_service::uninstall()?;
                #[cfg(not(windows))]
                anyhow::bail!("Windows service mode is only available on Windows");
            }
        },
    }

    let _ = append_log("command completed");
    let _ = thread::sleep(Duration::from_millis(1));
    Ok(())
}

#[cfg(windows)]
mod shield_windows_service {
    use super::*;
    use std::{env, ffi::OsString, process::Command, sync::mpsc, time::Duration};
    use windows_service::{
        define_windows_service,
        service::{
            ServiceControl, ServiceControlAccept, ServiceExitCode, ServiceState, ServiceStatus,
            ServiceType,
        },
        service_control_handler::{self, ServiceControlHandlerResult},
        service_dispatcher, service_manager::{ServiceAccess, ServiceManager, ServiceManagerAccess},
        service::{ServiceInfo, ServiceStartType},
    };

    define_windows_service!(ffi_service_main, service_main);

    pub fn dispatch() -> Result<()> {
        service_dispatcher::start(shield::SERVICE_NAME, ffi_service_main)
            .map_err(|e| anyhow::anyhow!("service dispatcher failed: {e}"))
    }

    pub fn install_current_executable() -> Result<()> {
        let exe = env::current_exe()?;
        let manager = ServiceManager::local_computer(None::<&str>, ServiceManagerAccess::CREATE_SERVICE)?;
        let info = ServiceInfo {
            name: OsString::from(shield::SERVICE_NAME),
            display_name: OsString::from(shield::SERVICE_DISPLAY_NAME),
            service_type: ServiceType::OWN_PROCESS,
            start_type: ServiceStartType::AutoStart,
            error_control: windows_service::service::ServiceErrorControl::Normal,
            executable_path: exe,
            launch_arguments: vec![OsString::from("service"), OsString::from("run")],
            dependencies: vec![],
            account_name: Some(OsString::from("LocalSystem")),
            account_password: None,
        };
        let service = manager.create_service(&info, ServiceAccess::START | ServiceAccess::QUERY_STATUS)?;
        service.set_description("SHIELD endpoint security and monitoring service.")?;
        service.start(&[])?;
        println!("SHIELD service installed and started.");
        Ok(())
    }

    pub fn uninstall() -> Result<()> {
        let manager = ServiceManager::local_computer(None::<&str>, ServiceManagerAccess::CONNECT)?;
        let service = manager.open_service(
            shield::SERVICE_NAME,
            ServiceAccess::STOP | ServiceAccess::DELETE | ServiceAccess::QUERY_STATUS,
        )?;
        let _ = service.stop();
        service.delete()?;
        println!("SHIELD service removed.");
        Ok(())
    }

    fn service_main(_arguments: Vec<OsString>) {
        if let Err(error) = service_loop() {
            let _ = append_log(&format!("service failed: {error:#}"));
        }
    }

    fn service_loop() -> Result<()> {
        let (shutdown_tx, shutdown_rx) = mpsc::channel::<()>();
        let event_handler = move |event| match event {
            ServiceControl::Stop | ServiceControl::Shutdown => {
                let _ = shutdown_tx.send(());
                ServiceControlHandlerResult::NoError
            }
            _ => ServiceControlHandlerResult::NoError,
        };

        let status_handle = service_control_handler::register(shield::SERVICE_NAME, event_handler)?;
        status_handle.set_service_status(ServiceStatus {
            service_type: ServiceType::OWN_PROCESS,
            current_state: ServiceState::Running,
            controls_accepted: ServiceControlAccept::STOP | ServiceControlAccept::SHUTDOWN,
            exit_code: ServiceExitCode::Win32(0),
            checkpoint: 0,
            wait_hint: Duration::default(),
            process_id: None,
        })?;

        append_log("service started")?;

        loop {
            let snapshot = build_snapshot(true, Some("heartbeat".to_owned()), None);
            let _ = write_state(&snapshot);

            if shutdown_rx.recv_timeout(Duration::from_secs(30)).is_ok() {
                break;
            }
        }

        let _ = write_state(&build_snapshot(false, Some("service stopped".to_owned()), None));
        append_log("service stopped")?;

        status_handle.set_service_status(ServiceStatus {
            service_type: ServiceType::OWN_PROCESS,
            current_state: ServiceState::Stopped,
            controls_accepted: ServiceControlAccept::empty(),
            exit_code: ServiceExitCode::Win32(0),
            checkpoint: 0,
            wait_hint: Duration::default(),
            process_id: None,
        })?;

        Ok(())
    }
}
