use anyhow::{Context, Result};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    fs::{self, File},
    io::Read,
    path::{Path, PathBuf},
};
#[cfg(windows)]
use std::process::Command;
use walkdir::WalkDir;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const SERVICE_NAME: &str = "SHIELD";
pub const SERVICE_DISPLAY_NAME: &str = "SHIELD Endpoint Security";

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DefenderStatus {
    #[serde(rename = "AMServiceEnabled")]
    pub service_enabled: Option<bool>,
    #[serde(rename = "AntivirusEnabled")]
    pub antivirus_enabled: Option<bool>,
    #[serde(rename = "AntispywareEnabled")]
    pub antispyware_enabled: Option<bool>,
    #[serde(rename = "RealTimeProtectionEnabled")]
    pub realtime_protection_enabled: Option<bool>,
    #[serde(rename = "AMRunningMode")]
    pub running_mode: Option<String>,
    #[serde(rename = "AMEngineVersion")]
    pub engine_version: Option<String>,
    #[serde(rename = "AntivirusSignatureVersion")]
    pub signature_version: Option<String>,
    #[serde(rename = "AntivirusSignatureLastUpdated")]
    pub signature_last_updated: Option<String>,
    #[serde(rename = "QuickScanEndTime")]
    pub quick_scan_end_time: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct YaraMatch {
    pub rule: String,
    pub namespace: String,
    pub path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThreatRecord {
    pub name: String,
    pub id: Option<i64>,
    pub resources: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateSnapshot {
    pub version: String,
    pub timestamp: String,
    pub service_heartbeat: bool,
    pub protection_enabled: bool,
    pub defender: Option<DefenderStatus>,
    pub threat_count: usize,
    pub last_action: Option<String>,
    pub last_error: Option<String>,
}

impl Default for StateSnapshot {
    fn default() -> Self {
        Self {
            version: VERSION.to_owned(),
            timestamp: Utc::now().to_rfc3339(),
            service_heartbeat: false,
            protection_enabled: false,
            defender: None,
            threat_count: 0,
            last_action: None,
            last_error: None,
        }
    }
}

pub fn data_dir() -> PathBuf {
    if let Ok(value) = std::env::var("SHIELD_DATA_DIR") {
        return PathBuf::from(value);
    }

    #[cfg(windows)]
    {
        return PathBuf::from(
            std::env::var("PROGRAMDATA").unwrap_or_else(|_| "C:\ProgramData".to_owned()),
        )
        .join("SHIELD");
    }

    #[cfg(not(windows))]
    {
        std::env::var("XDG_STATE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                std::env::var("HOME")
                    .map(|h| PathBuf::from(h).join(".local").join("state"))
                    .unwrap_or_else(|_| PathBuf::from("."))
            })
            .join("shield")
    }
}

pub fn state_path() -> PathBuf {
    data_dir().join("state.json")
}

pub fn log_path() -> PathBuf {
    data_dir().join("shield.log")
}

pub fn ensure_data_dir() -> Result<()> {
    fs::create_dir_all(data_dir()).context("creating SHIELD data directory")
}

pub fn write_state(state: &StateSnapshot) -> Result<()> {
    ensure_data_dir()?;
    let target = state_path();
    let temp = target.with_extension("json.tmp");
    fs::write(&temp, serde_json::to_vec_pretty(state)?)?;
    fs::rename(&temp, &target)?;
    Ok(())
}

pub fn read_state() -> Result<StateSnapshot> {
    let payload = fs::read(state_path()).context("reading SHIELD state")?;
    Ok(serde_json::from_slice(&payload)?)
}

pub fn append_log(message: &str) -> Result<()> {
    ensure_data_dir()?;
    use std::io::Write;
    let mut file = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_path())?;
    writeln!(file, "{} {}", Utc::now().to_rfc3339(), message)?;
    Ok(())
}

pub fn sha256_file(path: &Path) -> Result<String> {
    let mut file = File::open(path).with_context(|| format!("opening {}", path.display()))?;
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

pub fn scan_hashes(path: &Path) -> Result<(usize, usize)> {
    if path.is_file() {
        sha256_file(path)?;
        return Ok((1, 0));
    }
    if !path.is_dir() {
        anyhow::bail!("path does not exist: {}", path.display());
    }

    let mut scanned = 0;
    let mut errors = 0;
    for entry in WalkDir::new(path).follow_links(false) {
        let entry = match entry {
            Ok(value) => value,
            Err(_) => {
                errors += 1;
                continue;
            }
        };
        if entry.file_type().is_file() {
            match sha256_file(entry.path()) {
                Ok(_) => scanned += 1,
                Err(_) => errors += 1,
            }
        }
    }
    Ok((scanned, errors))
}

#[cfg(windows)]
fn powershell(script: &str) -> Result<String> {
    let output = Command::new("powershell.exe")
        .args([
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            script,
        ])
        .output()
        .context("starting Windows PowerShell")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        anyhow::bail!(
            "PowerShell command failed: {}",
            if stderr.is_empty() {
                "unknown error"
            } else {
                &stderr
            }
        );
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

pub fn default_yara_rules_dir() -> PathBuf {
    data_dir().join("rules")
}

pub fn yara_scan(target: &Path, rules_dir: &Path) -> Result<Vec<YaraMatch>> {
    if !rules_dir.exists() {
        anyhow::bail!("YARA rules directory does not exist: {}", rules_dir.display());
    }

    let mut compiler = yara_x::Compiler::new();
    let mut rule_files = 0usize;

    for entry in WalkDir::new(rules_dir).follow_links(false) {
        let entry = entry?;
        if !entry.file_type().is_file() {
            continue;
        }
        let extension = entry
            .path()
            .extension()
            .and_then(|v| v.to_str())
            .unwrap_or_default()
            .to_ascii_lowercase();
        if extension != "yar" && extension != "yara" {
            continue;
        }

        let source = fs::read_to_string(entry.path())
            .with_context(|| format!("reading YARA rule {}", entry.path().display()))?;
        compiler
            .add_source(source)
            .with_context(|| format!("compiling YARA rule {}", entry.path().display()))?;
        rule_files += 1;
    }

    if rule_files == 0 {
        anyhow::bail!("no .yar or .yara rule files found in {}", rules_dir.display());
    }

    let rules = compiler.build();
    let mut scanner = yara_x::Scanner::new(&rules);
    scanner.set_timeout(std::time::Duration::from_secs(30));
    scanner.max_matches_per_pattern(128);
    scanner.use_mmap(false);

    let mut matches = Vec::new();
    let targets: Box<dyn Iterator<Item = PathBuf>> = if target.is_file() {
        Box::new(std::iter::once(target.to_path_buf()))
    } else if target.is_dir() {
        Box::new(
            WalkDir::new(target)
                .follow_links(false)
                .into_iter()
                .filter_map(|entry| entry.ok())
                .filter(|entry| entry.file_type().is_file())
                .map(|entry| entry.path().to_path_buf()),
        )
    } else {
        anyhow::bail!("YARA target does not exist: {}", target.display());
    };

    for path in targets {
        let results = scanner
            .scan_file(&path)
            .with_context(|| format!("YARA scanning {}", path.display()))?;
        for rule in results.matching_rules() {
            matches.push(YaraMatch {
                rule: rule.identifier().to_owned(),
                namespace: rule.namespace().to_owned(),
                path: path.to_string_lossy().into_owned(),
            });
        }
    }

    Ok(matches)
}

#[cfg(windows)]
pub fn windows_defender_status() -> Result<DefenderStatus> {
    let script = r#"
$ErrorActionPreference='Stop'
Import-Module Defender
Get-MpComputerStatus |
Select-Object AMServiceEnabled,AntivirusEnabled,AntispywareEnabled,RealTimeProtectionEnabled,AMRunningMode,AMEngineVersion,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,QuickScanEndTime |
ConvertTo-Json -Compress
"#;
    let output = powershell(script)?;
    Ok(serde_json::from_str(&output).context("parsing Defender status")?)
}

#[cfg(not(windows))]
pub fn windows_defender_status() -> Result<DefenderStatus> {
    anyhow::bail!("Microsoft Defender integration is only available on Windows")
}

#[cfg(windows)]
pub fn windows_defender_threats() -> Result<Vec<ThreatRecord>> {
    let script = r#"
$ErrorActionPreference='Stop'
Import-Module Defender
Get-MpThreatDetection |
Select-Object ThreatID,ThreatName,Resources |
ConvertTo-Json -Depth 5 -Compress
"#;
    let output = powershell(script)?;
    if output.is_empty() {
        return Ok(Vec::new());
    }

    let value: serde_json::Value = serde_json::from_str(&output)?;
    let values = if let Some(array) = value.as_array() {
        array.clone()
    } else {
        vec![value]
    };

    let mut threats = Vec::new();
    for item in values {
        let resources = item
            .get("Resources")
            .and_then(|v| v.as_array())
            .map(|items| {
                items
                    .iter()
                    .filter_map(|v| v.as_str().map(str::to_owned))
                    .collect()
            })
            .unwrap_or_default();

        threats.push(ThreatRecord {
            name: item
                .get("ThreatName")
                .and_then(|v| v.as_str())
                .unwrap_or("Unknown threat")
                .to_owned(),
            id: item.get("ThreatID").and_then(|v| v.as_i64()),
            resources,
        });
    }

    Ok(threats)
}

#[cfg(not(windows))]
pub fn windows_defender_threats() -> Result<Vec<ThreatRecord>> {
    Ok(Vec::new())
}

#[cfg(windows)]
pub fn windows_defender_scan(scan_type: &str, path: Option<&Path>) -> Result<()> {
    let scan_type = match scan_type {
        "quick" => "QuickScan",
        "full" => "FullScan",
        "custom" => "CustomScan",
        _ => anyhow::bail!("unsupported Defender scan type: {scan_type}"),
    };

    let path_clause = match path {
        Some(value) if scan_type == "CustomScan" => {
            let escaped = value.to_string_lossy().replace('\'', "''");
            format!(" -ScanPath '{}'", escaped)
        }
        _ => String::new(),
    };

    let script = format!(
        "$ErrorActionPreference='Stop'; Import-Module Defender; Start-MpScan -ScanType {}{}",
        scan_type, path_clause
    );
    powershell(&script)?;
    Ok(())
}

#[cfg(not(windows))]
pub fn windows_defender_scan(_scan_type: &str, _path: Option<&Path>) -> Result<()> {
    anyhow::bail!("Microsoft Defender integration is only available on Windows")
}

#[cfg(windows)]
pub fn windows_defender_update() -> Result<()> {
    powershell("$ErrorActionPreference='Stop'; Import-Module Defender; Update-MpSignature")?;
    Ok(())
}

#[cfg(not(windows))]
pub fn windows_defender_update() -> Result<()> {
    anyhow::bail!("Microsoft Defender integration is only available on Windows")
}

pub fn build_snapshot(
    service_heartbeat: bool,
    last_action: Option<String>,
    last_error: Option<String>,
) -> StateSnapshot {
    let defender = windows_defender_status().ok();
    let threat_count = windows_defender_threats()
        .map(|items| items.len())
        .unwrap_or(0);
    let protection_enabled = defender
        .as_ref()
        .and_then(|d| d.realtime_protection_enabled)
        .unwrap_or(false);

    StateSnapshot {
        version: VERSION.to_owned(),
        timestamp: Utc::now().to_rfc3339(),
        service_heartbeat,
        protection_enabled,
        defender,
        threat_count,
        last_action,
        last_error,
    }
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
