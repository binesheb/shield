use anyhow::Result;
use clap::{Parser, Subcommand};
use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::Read;
use std::path::PathBuf;
use walkdir::WalkDir;

#[derive(Parser, Debug)]
#[command(name = "shield", version, about = "Open-source endpoint security platform")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Show local SHIELD status.
    Status,
    /// Scan a file or directory and calculate SHA-256 hashes.
    Scan {
        /// File or directory to scan.
        path: PathBuf,
    },
    /// Show SHIELD version.
    Version,
}

fn sha256_file(path: &PathBuf) -> Result<String> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 1024 * 64];

    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 { break; }
        hasher.update(&buffer[..read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

fn scan(path: &PathBuf) -> Result<()> {
    if path.is_file() {
        let hash = sha256_file(path)?;
        println!("FILE\t{}\tSHA256\t{}", path.display(), hash);
        return Ok(());
    }

    if path.is_dir() {
        for entry in WalkDir::new(path).follow_links(false) {
            let entry = entry?;
            if entry.file_type().is_file() {
                let file_path = entry.path().to_path_buf();
                match sha256_file(&file_path) {
                    Ok(hash) => println!("FILE\t{}\tSHA256\t{}", file_path.display(), hash),
                    Err(error) => eprintln!("ERROR\t{}\t{}", file_path.display(), error),
                }
            }
        }
        return Ok(());
    }

    anyhow::bail!("path does not exist: {}", path.display());
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Status => {
            println!("SHIELD {}", env!("CARGO_PKG_VERSION"));
            println!("Protection: foundation-only");
            println!("Scanner: SHA-256");
        }
        Commands::Scan { path } => scan(&path)?,
        Commands::Version => println!("{}", env!("CARGO_PKG_VERSION")),
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
        assert_eq!(hash, "072a626ed2d6cc7d5da0fcc388f3067b49c93bcd23b5109888ceefc4296f53b6");
    }
}
