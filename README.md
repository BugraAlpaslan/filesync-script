# File Synchronization Tool

A comprehensive file synchronization tool with both CLI and GUI interfaces, developed as an Operating Systems course project.

## Features

### Core Functionality
- **One-way synchronization**: Source → Target (standard backup mode)
- **Two-way synchronization**: Bidirectional sync between folders
- **Smart file detection**: MD5 hash-based change detection
- **Size filtering**: Configurable file size limits (default: 100 MB)
- **Dry-run mode**: Preview operations without making changes
- **Verbose logging**: Detailed operation logs with timestamps
- **Persistent settings**: Remembers your preferences between sessions

### User Interfaces
1. **Command Line Interface (CLI)**: `sync_tool.sh` - Fast, scriptable operations
2. **Graphical Interface (GUI)**: `gui.sh` - User-friendly Zenity-based interface

## Requirements

### For CLI
- Bash shell
- Standard Unix utilities (cp, rm, find, stat)
- MD5 checksum tools (md5sum or md5)

### For GUI
- All CLI requirements
- Zenity (graphical dialogs)
  ```bash
  # Ubuntu/Debian
  sudo apt install zenity
  
  # Fedora/RHEL
  sudo dnf install zenity
  
  # Arch Linux
  sudo pacman -S zenity
  ```

## Installation

1. Clone or download the repository
2. Make scripts executable:
   ```bash
   chmod +x sync_tool.sh gui.sh test_sync.sh
   ```

## Usage

### Graphical Interface (Recommended for beginners)

```bash
./gui.sh
```

Features:
- Interactive folder selection
- Visual progress indicators
- Configuration menu for advanced settings
- Log viewer for previous synchronizations
- Built-in help system

### Command Line Interface

**Basic syntax:**
```bash
./sync_tool.sh <source_folder> <target_folder> [options]
```

**Options:**
```
-l, --log <file>      Log file name (default: sync.log)
-t, --two-way         Two-way synchronization
-d, --dry-run         Preview mode (no actual changes)
-v, --verbose         Detailed output
-h, --help            Show help message
```

**Examples:**

Simple backup:
```bash
./sync_tool.sh ~/Documents ~/Backup
```

Two-way sync with custom log:
```bash
./sync_tool.sh ~/FolderA ~/FolderB --two-way -l sync_report.txt
```

Dry-run with verbose output:
```bash
./sync_tool.sh ~/Source ~/Target --dry-run --verbose
```

## How It Works

### Synchronization Process

1. **Scanning**: Recursively scans source directory for files
2. **Comparison**: Compares files using MD5 hashes
3. **Classification**: Identifies new, modified, and deleted files
4. **Execution**: Performs copy/update/delete operations
5. **Logging**: Records all operations with timestamps

### File Operations

- **Copy**: New files from source → target
- **Update**: Modified files (different hash) are overwritten
- **Delete**: Files removed from source are deleted in target (one-way mode)
- **Skip**: Unchanged files and oversized files

### Two-Way Synchronization

In two-way mode:
1. First pass: Source → Target
2. Second pass: Target → Source
3. Both directories end up with all files from both sides

**Note**: Conflicts (same file modified in both locations) are resolved by timestamp - newer version wins.

## Configuration

### GUI Settings
Access via "Advanced Settings" menu:
- Synchronization mode (one-way/two-way)
- Dry-run toggle
- Verbose output
- Maximum file size
- Custom log file name

Settings are automatically saved to `~/.sync_config`

### File Size Limit
Default: 100 MB per file

Modify in script:
```bash
MAX_FILE_SIZE=$((100 * 1024 * 1024))  # bytes
```

Or in GUI: Advanced Settings → Maximum File Size

## Log Files

Logs are stored in `~/.sync_logs/` with format: `sync_YYYYMMDD_HHMMSS.log`

**Log entries include:**
- Timestamp for each operation
- Operation type (COPY, UPDATE, DELETE, SKIP, ERROR)
- File paths
- File sizes
- Error messages if any

**View logs:**
- GUI: "View Past Logs" menu
- CLI: `cat ~/.sync_logs/sync_*.log`

## Testing

Run the comprehensive test suite:
```bash
./test_sync.sh
```

**Test coverage:**
1. Basic file copying
2. Subdirectory support
3. File update detection
4. Deletion handling
5. Large file filtering
6. Multi-file performance (100 files)
7. Special characters in filenames
8. Empty directory handling
9. Dry-run mode verification
10. Two-way synchronization
11. File permissions
12. Symbolic links
13. Various file formats
14. Sequential syncs
15. Error handling

## Project Structure

```
.
├── sync_tool.sh      # Core synchronization engine (CLI)
├── gui.sh            # Graphical interface wrapper
├── test_sync.sh      # Automated test suite
├── .gitattributes    # Git configuration (LF line endings)
└── README.md         # This file
```

## Use Cases

### Personal Backup
```bash
./sync_tool.sh ~/Documents ~/Backup/Documents -l backup.log
```

### Project Synchronization
```bash
./sync_tool.sh ~/Projects/MyApp /media/usb/MyApp --two-way
```

### Safe Testing
```bash
# Preview changes first
./sync_tool.sh ~/Source ~/Target --dry-run -v

# If OK, run for real
./sync_tool.sh ~/Source ~/Target
```

### Automated Backups
Add to crontab for daily backups:
```bash
0 2 * * * /path/to/sync_tool.sh ~/Documents ~/Backup/Documents -l ~/logs/backup.log
```

## Limitations

- Files larger than 100 MB are skipped by default
- Symbolic links are followed (target content is copied)
- Empty directories are not preserved
- No compression or encryption
- Two-way sync conflict resolution is timestamp-based only

## Safety Features

- **Dry-run mode**: Test before making changes
- **Detailed logging**: Full audit trail
- **Hash verification**: Prevents unnecessary copies
- **Size limits**: Protects against huge files
- **Error handling**: Continues on errors, logs all issues

## Troubleshooting

**GUI doesn't start:**
- Install Zenity: `sudo apt install zenity`
- Check if script is executable: `chmod +x gui.sh`

**Permissions denied:**
- Ensure you have read access to source folder
- Ensure you have write access to target folder

**Files not updating:**
- Check file modification times
- Try with `--verbose` flag to see details

**Large files skipped:**
- Check log for "SKIPPED: Size limit exceeded"
- Increase size limit in script if needed

## License

This is an educational project developed for an Operating Systems course. Feel free to use and modify as needed.

## Contributing

Suggestions and improvements are welcome! This project demonstrates:
- File system operations
- Process management
- Shell scripting
- User interface design
- Error handling
- Automated testing

## Author
Buğra Alpaslan
Operating Systems Course Project

---

**Quick Start:**
1. Download scripts
2. Run `./gui.sh` for graphical interface
3. Or use `./sync_tool.sh source target` for CLI
4. Check logs in `~/.sync_logs/`
