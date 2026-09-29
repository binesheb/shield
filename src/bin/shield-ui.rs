use eframe::egui;
use shield::{
    read_state, windows_defender_scan, windows_defender_status, windows_defender_threats,
    windows_defender_update, DefenderStatus, StateSnapshot, ThreatRecord, VERSION,
};
use std::path::PathBuf;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Page {
    Dashboard,
    Scan,
    Threats,
    Protection,
}

struct ShieldApp {
    page: Page,
    state: StateSnapshot,
    threats: Vec<ThreatRecord>,
    scan_path: String,
    busy: bool,
    message: String,
}

impl ShieldApp {
    fn new(_cc: &eframe::CreationContext<'_>) -> Self {
        let state = read_state().unwrap_or_default();
        let threats = windows_defender_threats().unwrap_or_default();
        Self {
            page: Page::Dashboard,
            state,
            threats,
            scan_path: String::new(),
            busy: false,
            message: String::from("Ready"),
        }
    }

    fn refresh(&mut self) {
        self.state = read_state().unwrap_or_else(|_| {
            let mut fallback = StateSnapshot::default();
            fallback.defender = windows_defender_status().ok();
            fallback.threat_count = windows_defender_threats().map(|v| v.len()).unwrap_or(0);
            fallback.protection_enabled = fallback
                .defender
                .as_ref()
                .and_then(|d| d.realtime_protection_enabled)
                .unwrap_or(false);
            fallback
        });
        self.threats = windows_defender_threats().unwrap_or_default();
    }

    fn start_scan(&mut self, kind: &str, path: Option<PathBuf>) {
        self.busy = true;
        self.message = format!("Starting {kind} scan...");
        let result = windows_defender_scan(kind, path.as_deref());
        self.message = match result {
            Ok(()) => format!("Windows Defender {kind} scan started."),
            Err(error) => format!("Scan failed: {error}"),
        };
        self.busy = false;
        self.refresh();
    }

    fn update_signatures(&mut self) {
        self.busy = true;
        self.message = "Updating Microsoft Defender signatures...".to_owned();
        self.message = match windows_defender_update() {
            Ok(()) => "Signature update requested.".to_owned(),
            Err(error) => format!("Signature update failed: {error}"),
        };
        self.busy = false;
        self.refresh();
    }

    fn top_bar(&mut self, ctx: &egui::Context) {
        egui::TopBottomPanel::top("top").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.heading("SHIELD");
                ui.separator();
                ui.label("Security Center");
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    let protection = self
                        .state
                        .defender
                        .as_ref()
                        .and_then(|d| d.realtime_protection_enabled)
                        .unwrap_or(false);
                    ui.colored_label(
                        if protection { egui::Color32::from_rgb(50, 190, 100) } else { egui::Color32::from_rgb(230, 150, 50) },
                        if protection { "● PROTECTED" } else { "● ATTENTION" },
                    );
                    ui.label(format!("v{VERSION}"));
                });
            });
        });
    }

    fn navigation(&mut self, ctx: &egui::Context) {
        egui::SidePanel::left("navigation")
            .resizable(false)
            .default_width(180.0)
            .show(ctx, |ui| {
                ui.add_space(12.0);
                ui.heading("SHIELD");
                ui.label("Binesh OS Security");
                ui.add_space(18.0);

                for (page, label) in [
                    (Page::Dashboard, "Dashboard"),
                    (Page::Scan, "Scan"),
                    (Page::Threats, "Threats"),
                    (Page::Protection, "Protection"),
                ] {
                    if ui.selectable_label(self.page == page, label).clicked() {
                        self.page = page;
                    }
                }

                ui.add_space(20.0);
                if ui.button("↻ Refresh").clicked() {
                    self.refresh();
                    self.message = "Status refreshed.".to_owned();
                }
                ui.separator();
                ui.small(&self.message);
            });
    }

    fn dashboard(&mut self, ui: &mut egui::Ui) {
        ui.heading("Security overview");
        ui.label("SHIELD monitors the endpoint and exposes the operating system security state.");
        ui.add_space(16.0);

        let protection = self
            .state
            .defender
            .as_ref()
            .and_then(|d| d.realtime_protection_enabled)
            .unwrap_or(false);

        ui.columns(3, |columns| {
            columns[0].group(|ui| {
                ui.heading(if protection { "Protected" } else { "Attention" });
                ui.label(if protection {
                    "Real-time protection is enabled."
                } else {
                    "Real-time protection is not confirmed."
                });
            });
            columns[1].group(|ui| {
                ui.heading(self.state.threat_count.to_string());
                ui.label("Reported Defender detections");
            });
            columns[2].group(|ui| {
                ui.heading(if self.state.service_heartbeat { "Running" } else { "Not running" });
                ui.label("SHIELD service heartbeat");
            });
        });

        ui.add_space(20.0);
        ui.heading("Protection engine");
        if let Some(defender) = &self.state.defender {
            status_row(ui, "Service", bool_text(defender.service_enabled));
            status_row(ui, "Antivirus", bool_text(defender.antivirus_enabled));
            status_row(ui, "Antispyware", bool_text(defender.antispyware_enabled));
            status_row(ui, "Real-time", bool_text(defender.realtime_protection_enabled));
            status_row(ui, "Mode", defender.running_mode.as_deref().unwrap_or("Unknown"));
            status_row(ui, "Engine", defender.engine_version.as_deref().unwrap_or("Unknown"));
            status_row(ui, "Signatures", defender.signature_version.as_deref().unwrap_or("Unknown"));
            status_row(ui, "Last quick scan", defender.quick_scan_end_time.as_deref().unwrap_or("Unknown"));
        } else {
            ui.colored_label(egui::Color32::from_rgb(220, 80, 80), "Microsoft Defender status is unavailable.");
        }
    }

    fn scan_page(&mut self, ui: &mut egui::Ui) {
        ui.heading("Scan");
        ui.label("SHIELD delegates Windows malware scanning to Microsoft Defender on Windows.");
        ui.add_space(16.0);

        ui.horizontal(|ui| {
            if ui.add_enabled(!self.busy, egui::Button::new("Quick scan")).clicked() {
                self.start_scan("quick", None);
            }
            if ui.add_enabled(!self.busy, egui::Button::new("Full scan")).clicked() {
                self.start_scan("full", None);
            }
        });

        ui.add_space(18.0);
        ui.separator();
        ui.label("Custom path");
        ui.text_edit_singleline(&mut self.scan_path);
        if ui
            .add_enabled(
                !self.busy && !self.scan_path.trim().is_empty(),
                egui::Button::new("Scan path"),
            )
            .clicked()
        {
            self.start_scan("custom", Some(PathBuf::from(self.scan_path.trim())));
        }

        ui.add_space(20.0);
        ui.label("For an independent hash-only scan, use:");
        ui.code("shield scan <path>");
    }

    fn threats_page(&mut self, ui: &mut egui::Ui) {
        ui.heading("Threat history");
        ui.label("Detections reported by Microsoft Defender.");
        ui.add_space(12.0);

        if self.threats.is_empty() {
            ui.group(|ui| {
                ui.label("No Defender threat detections were returned.");
            });
            return;
        }

        egui::ScrollArea::vertical().show(ui, |ui| {
            for threat in &self.threats {
                ui.group(|ui| {
                    ui.strong(&threat.name);
                    if let Some(id) = threat.id {
                        ui.label(format!("Threat ID: {id}"));
                    }
                    for resource in &threat.resources {
                        ui.monospace(resource);
                    }
                });
                ui.add_space(6.0);
            }
        });
    }

    fn protection_page(&mut self, ui: &mut egui::Ui) {
        ui.heading("Protection controls");
        ui.label("SHIELD does not silently disable or weaken the operating system's security controls.");
        ui.add_space(18.0);

        if ui
            .add_enabled(!self.busy, egui::Button::new("Update Defender signatures"))
            .clicked()
        {
            self.update_signatures();
        }

        ui.add_space(12.0);
        ui.group(|ui| {
            ui.label("Windows Defender is the active Windows protection provider.");
            ui.label("SHIELD reports its state, starts supported scans, and records security health.");
        });

        ui.add_space(12.0);
        ui.small("Advanced policy changes are intentionally not exposed in this release.");
    }
}

fn bool_text(value: Option<bool>) -> &'static str {
    match value {
        Some(true) => "Enabled",
        Some(false) => "Disabled",
        None => "Unknown",
    }
}

fn status_row(ui: &mut egui::Ui, name: &str, value: &str) {
    ui.horizontal(|ui| {
        ui.label(name);
        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
            ui.monospace(value);
        });
    });
}

impl eframe::App for ShieldApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.top_bar(ctx);
        self.navigation(ctx);

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(16.0);
            match self.page {
                Page::Dashboard => self.dashboard(ui),
                Page::Scan => self.scan_page(ui),
                Page::Threats => self.threats_page(ui),
                Page::Protection => self.protection_page(ui),
            }
            ui.add_space(12.0);
            ui.separator();
            ui.small("Local-first • Open source • Binesh OS security layer");
        });

        ctx.request_repaint_after(std::time::Duration::from_secs(5));
    }
}

fn main() -> eframe::Result {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("SHIELD Security Center")
            .with_inner_size([1100.0, 720.0])
            .with_min_inner_size([900.0, 600.0]),
        ..Default::default()
    };

    eframe::run_native(
        "SHIELD Security Center",
        options,
        Box::new(|cc| Ok(Box::new(ShieldApp::new(cc)))),
    )
}
