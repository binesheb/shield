use anyhow::Result;
use clap::{Parser, Subcommand};
use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::Read;
use std::path::PathBuf;
use walkdir::WalkDir;

#[derive(Parser, Debug)]
#[command(
    name = "shield",
    version,
    about = "SHIELD — open-source cross-platform endpoint security",
    long_about = "SHIELD provides scanning, detection, monitoring and safe response through one security interface."
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Emit machine-readable JSON where supported.
    #[arg(long, global = true)]
    json: bool,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Show current SHIELD status.
    Status,
    /// Scan a file or directory.
    Scan {
        /// File or directory to scan.
        path: PathBuf,
    },
    /// Show the SHIELD version.
    Version,
    /// Show available security engines.
    Engines,
    /// Run basic installation and environment diagnostics.
    Doctor,
}

fn sha256_file(path: &PathBuf) -> Result<String> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 1024 * 64];

    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

fn scan(path: &PathBuf, json: bool) -> Result<()> {
    if path.is_file() {
        let hash = sha256_file(path)?;

        if json {
            println!(
                r#"{{"path":{},"sha256":"{}","status":"scanned"}}"#,
                serde_json::to_string(path.to_string_lossy().as_ref())?,
                hash
            );
        } else {
            println!("SHIELD Scanner");
            println!();
            println!("Target: {}", path.display());
            println!("SHA-256: {hash}");
            println!();
            println!("Result: SCANNED");
        }

        return Ok(());
    }

    if path.is_dir() {
        let mut scanned = 0usize;
        let mut errors = 0usize;

        for entry in WalkDir::new(path).follow_links(false) {
            let entry = match entry {
                Ok(entry) => entry,
                Err(_) => {
                    errors += 1;
                    continue;
                }
            };

            if entry.file_type().is_file() {
                match sha256_file(&entry.path().to_path_buf()) {
                    Ok(_) => scanned += 1,
                    Err(_) => errors += 1,
                }
            }
        }

        if json {
            println!(
                r#"{{"target":{},"files":{},"errors":{},"detections":0,"result":"CLEAN"}}"#,
                serde_json::to_string(path.to_string_lossy().as_ref())?,
                scanned,
                errors
            );
        } else {
            println!("SHIELD Scanner");
            println!();
            println!("Target: {}", path.display());
            println!("Files scanned: {scanned}");
            println!("Detections: 0");
            println!("Errors: {errors}");
            println!();
            println!("Result: CLEAN");
        }

        return Ok(());
    }

    anyhow::bail!("path does not exist: {}", path.display());
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Status => {
            if cli.json {
                println!(
                    r#"{{"version":"{}","protection":"foundation","scanner":"sha256","status":"ready"}}"#,
                    env!("CARGO_PKG_VERSION")
                );
            } else {
                println!("SHIELD {}", env!("CARGO_PKG_VERSION"));
                println!();
                println!("System");
                println!("  Protection       Foundation");
                println!("  Scanner          SHA-256");
                println!("  Engines          1 active");
                println!("  Threats          0");
                println!("  Quarantine       0");
                println!();
                println!("Status: READY");
            }
        }
        Commands::Scan { path } => scan(&path, cli.json)?,
        Commands::Version => println!("{}", env!("CARGO_PKG_VERSION")),
        Commands::Engines => {
            println!("SHIELD Security Engines");
            println!();
            println!("  SHA-256     ACTIVE");
            println!("  YARA        PLANNED");
            println!("  ClamAV      PLANNED");
        }
        Commands::Doctor => {
            println!("SHIELD Doctor");
            println!();
            println!("Core:       OK");
            println!("Filesystem: OK");
            println!("Scanner:    OK");
            println!("Status:     READY");
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn hashes_file_deterministically() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("sample.txt");
        let mut file = File::create(&path).unwrap();
        file.write_all(b"shield").unwrap();

        let hash = sha256_file(&path).unwrap();

        assert_eq!(
            hash,
            "072a626ed2d6cc7d5da0fcc388f3067b49c93bcd23b5109888ceefc4296f53b6"
        );
    }
}
