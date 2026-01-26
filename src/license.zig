const std = @import("std");
const models = @import("models.zig");

pub const KeygenConfig = struct {
    pub const server_url: []const u8 = "https://license.example.com";
    pub const account_id: []const u8 = "YOUR_ACCOUNT_ID";
    pub const product_id: []const u8 = "YOUR_PRODUCT_ID";
    pub const policy_id: []const u8 = "YOUR_POLICY_ID";
    pub const max_machines: u8 = 2;

    /// License cache validity in seconds (for offline mode)
    pub const cache_validity_seconds: u64 = 7 * 24 * 60 * 60;

    /// Application version for validation
    pub const app_version: []const u8 = "1.0.0";
};

pub const LicenseStatus = enum {
    not_configured,
    valid,
    not_activated,
    invalid,
    activation_limit_reached,
    suspended,
    network_error,
    cached,

    pub fn isUsable(self: LicenseStatus) bool {
        return self == .valid or self == .cached;
    }

    pub fn getMessage(self: LicenseStatus) []const u8 {
        return switch (self) {
            .not_configured => "No license key configured",
            .valid => "License is valid",
            .not_activated => "License not activated on this machine",
            .invalid => "Invalid license key",
            .activation_limit_reached => "Machine activation limit reached (max 5)",
            .suspended => "License has been suspended",
            .network_error => "Unable to connect to license server",
            .cached => "License valid (offline mode)",
        };
    }
};

/// Machine fingerprint for activation
pub const MachineFingerprint = struct {
    fingerprint: models.BoundedString(128) = .{},
    hostname: models.BoundedString(64) = .{},
    platform: models.BoundedString(32) = .{},

    pub fn generate() MachineFingerprint {
        var fp = MachineFingerprint{};
        fp.platform.set("linux");

        // Get hostname
        var hostname_buf: [64]u8 = undefined;
        if (getHostname(&hostname_buf)) |hostname| {
            fp.hostname.set(hostname);
        } else {
            fp.hostname.set("unknown");
        }

        // Generate fingerprint from machine-id and MAC addresses
        var fingerprint_buf: [128]u8 = undefined;
        if (generateMachineFingerprint(&fingerprint_buf)) |fingerprint| {
            fp.fingerprint.set(fingerprint);
        } else {
            // Fallback: use hostname-based fingerprint
            var fallback_buf: [128]u8 = undefined;
            const fallback = std.fmt.bufPrint(&fallback_buf, "fallback-{s}", .{fp.hostname.get()}) catch "unknown";
            fp.fingerprint.set(fallback);
        }

        return fp;
    }

    pub fn getFingerprint(self: *const MachineFingerprint) []const u8 {
        return self.fingerprint.get();
    }
};

/// Cached license data stored locally
pub const LicenseCache = struct {
    license_key: models.BoundedString(256) = .{},
    machine_id: models.BoundedString(64) = .{},
    machine_fingerprint: models.BoundedString(128) = .{},
    validated_at: i64 = 0,
    status: LicenseStatus = .not_configured,

    /// License metadata
    licensee_name: models.BoundedString(128) = .{},
    licensee_email: models.BoundedString(128) = .{},

    pub fn isValid(self: *const LicenseCache) bool {
        if (self.status != .valid and self.status != .cached) return false;
        if (self.license_key.isEmpty()) return false;
        if (self.machine_id.isEmpty()) return false;

        // Check cache expiry
        const now = std.time.timestamp();
        const age: u64 = @intCast(@max(0, now - self.validated_at));
        return age < KeygenConfig.cache_validity_seconds;
    }

    pub fn setLicenseKey(self: *LicenseCache, key: []const u8) void {
        self.license_key.set(key);
    }

    pub fn getLicenseKey(self: *const LicenseCache) []const u8 {
        return self.license_key.get();
    }
};

/// License manager handles all license operations
pub const LicenseManager = struct {
    allocator: std.mem.Allocator,
    cache: LicenseCache,
    fingerprint: MachineFingerprint,
    last_error: models.BoundedString(256) = .{},

    pub fn init(allocator: std.mem.Allocator) LicenseManager {
        var manager = LicenseManager{
            .allocator = allocator,
            .cache = LicenseCache{},
            .fingerprint = MachineFingerprint.generate(),
        };

        // Try to load cached license
        manager.loadCache();

        return manager;
    }

    pub fn deinit(self: *LicenseManager) void {
        _ = self;
    }

    /// Check if the current license is valid (either online or cached)
    pub fn isLicensed(self: *LicenseManager) bool {
        return self.cache.isValid();
    }

    /// Get current license status
    pub fn getStatus(self: *const LicenseManager) LicenseStatus {
        return self.cache.status;
    }

    /// Get last error message
    pub fn getLastError(self: *const LicenseManager) []const u8 {
        const err = self.last_error.get();
        if (err.len > 0) return err;
        return self.cache.status.getMessage();
    }

    /// Validate and activate a license key
    pub fn activateLicense(self: *LicenseManager, license_key: []const u8) LicenseStatus {
        self.last_error.clear();

        // First, validate the license key
        const validation_result = self.validateLicenseKey(license_key);
        if (validation_result != .valid and validation_result != .not_activated) {
            self.cache.status = validation_result;
            return validation_result;
        }

        // If not already activated, activate this machine
        if (validation_result == .not_activated) {
            const activation_result = self.activateMachine(license_key);
            if (activation_result != .valid) {
                self.cache.status = activation_result;
                return activation_result;
            }
        }

        // Success - update cache
        self.cache.setLicenseKey(license_key);
        self.cache.machine_fingerprint.set(self.fingerprint.getFingerprint());
        self.cache.validated_at = std.time.timestamp();
        self.cache.status = .valid;
        self.saveCache();

        return .valid;
    }

    /// Deactivate the current machine
    pub fn deactivateMachine(self: *LicenseManager) bool {
        if (self.cache.machine_id.isEmpty()) return false;

        const machine_id = self.cache.machine_id.get();
        const license_key = self.cache.getLicenseKey();

        // Build URL
        var url_buf: [512]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "{s}/v1/accounts/{s}/machines/{s}", .{
            KeygenConfig.server_url,
            KeygenConfig.account_id,
            machine_id,
        }) catch return false;

        // Make DELETE request
        const result = self.httpDelete(url, license_key);
        if (result) {
            // Clear cache
            self.cache = LicenseCache{};
            self.deleteCache();
            return true;
        }

        return false;
    }

    /// Validate license key with the server
    fn validateLicenseKey(self: *LicenseManager, license_key: []const u8) LicenseStatus {
        // Build request URL
        var url_buf: [512]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "{s}/v1/accounts/{s}/licenses/actions/validate-key", .{
            KeygenConfig.server_url,
            KeygenConfig.account_id,
        }) catch return .network_error;

        // Build JSON body
        var body_buf: [1024]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf,
            \\{{"meta":{{"key":"{s}","scope":{{"fingerprint":"{s}","product":"{s}"}}}}}}
        , .{
            license_key,
            self.fingerprint.getFingerprint(),
            KeygenConfig.product_id,
        }) catch return .network_error;

        // Make HTTP request
        var response_buf: [4096]u8 = undefined;
        const response = self.httpPost(url, body, &response_buf) catch {
            // Network error - check cache
            if (self.cache.isValid() and std.mem.eql(u8, self.cache.getLicenseKey(), license_key)) {
                return .cached;
            }
            return .network_error;
        };

        // Parse response
        return self.parseValidationResponse(response, license_key);
    }

    /// Activate this machine for the license
    fn activateMachine(self: *LicenseManager, license_key: []const u8) LicenseStatus {
        // First, get the license ID
        const license_id = self.getLicenseId(license_key) catch {
            return .network_error;
        };

        // Build request URL
        var url_buf: [512]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "{s}/v1/accounts/{s}/machines", .{
            KeygenConfig.server_url,
            KeygenConfig.account_id,
        }) catch return .network_error;

        // Build JSON body
        var body_buf: [2048]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf,
            \\{{"data":{{"type":"machines","attributes":{{"fingerprint":"{s}","name":"{s}","platform":"{s}"}},"relationships":{{"license":{{"data":{{"type":"licenses","id":"{s}"}}}}}}}}}}
        , .{
            self.fingerprint.getFingerprint(),
            self.fingerprint.hostname.get(),
            self.fingerprint.platform.get(),
            license_id,
        }) catch return .network_error;

        // Make HTTP request
        var response_buf: [4096]u8 = undefined;
        const response = self.httpPostWithAuth(url, body, license_key, &response_buf) catch {
            return .network_error;
        };

        // Parse response to get machine ID
        return self.parseActivationResponse(response);
    }

    /// Get license ID from license key
    fn getLicenseId(self: *LicenseManager, license_key: []const u8) ![]const u8 {
        _ = self;
        // The license key itself is often the ID in Keygen, or we need to look it up
        // For simplicity, we'll use the key as the lookup mechanism
        // In a real implementation, you might need to store the license ID from validation
        return license_key;
    }

    /// Parse license validation response
    fn parseValidationResponse(self: *LicenseManager, response: []const u8, license_key: []const u8) LicenseStatus {
        // Simple JSON parsing for the validation response
        // Looking for: "valid": true/false and "code": "..."

        // Check for valid field
        if (std.mem.indexOf(u8, response, "\"valid\":true") != null or
            std.mem.indexOf(u8, response, "\"valid\": true") != null)
        {
            // License is valid, check if activated on this machine
            if (std.mem.indexOf(u8, response, "NO_MACHINES") != null or
                std.mem.indexOf(u8, response, "NO_MACHINE") != null)
            {
                return .not_activated;
            }

            // Check for fingerprint scope match
            if (std.mem.indexOf(u8, response, "FINGERPRINT_SCOPE_MISMATCH") != null) {
                return .not_activated;
            }

            // Extract machine ID if present
            if (self.extractMachineId(response)) |machine_id| {
                self.cache.machine_id.set(machine_id);
            }

            // Extract licensee info
            self.extractLicenseeInfo(response);

            self.cache.setLicenseKey(license_key);
            return .valid;
        }

        // Check error codes
        if (std.mem.indexOf(u8, response, "NOT_FOUND") != null or
            std.mem.indexOf(u8, response, "LICENSE_INVALID") != null)
        {
            self.last_error.set("Invalid license key");
            return .invalid;
        }

        if (std.mem.indexOf(u8, response, "SUSPENDED") != null) {
            self.last_error.set("License has been suspended");
            return .suspended;
        }

        if (std.mem.indexOf(u8, response, "TOO_MANY_MACHINES") != null or
            std.mem.indexOf(u8, response, "MACHINE_LIMIT_EXCEEDED") != null)
        {
            self.last_error.set("Machine activation limit reached (max 5 machines)");
            return .activation_limit_reached;
        }

        self.last_error.set("License validation failed");
        return .invalid;
    }

    /// Parse machine activation response
    fn parseActivationResponse(self: *LicenseManager, response: []const u8) LicenseStatus {
        // Check for success
        if (std.mem.indexOf(u8, response, "\"type\":\"machines\"") != null or
            std.mem.indexOf(u8, response, "\"type\": \"machines\"") != null)
        {
            // Extract machine ID
            if (self.extractMachineId(response)) |machine_id| {
                self.cache.machine_id.set(machine_id);
                return .valid;
            }
        }

        // Check for errors
        if (std.mem.indexOf(u8, response, "MACHINE_LIMIT_EXCEEDED") != null or
            std.mem.indexOf(u8, response, "TOO_MANY_MACHINES") != null)
        {
            self.last_error.set("Machine activation limit reached (max 5 machines)");
            return .activation_limit_reached;
        }

        if (std.mem.indexOf(u8, response, "FINGERPRINT_TAKEN") != null) {
            // Machine already activated - this is actually OK
            if (self.extractMachineId(response)) |machine_id| {
                self.cache.machine_id.set(machine_id);
            }
            return .valid;
        }

        self.last_error.set("Failed to activate machine");
        return .invalid;
    }

    /// Extract machine ID from response JSON
    fn extractMachineId(self: *LicenseManager, response: []const u8) ?[]const u8 {
        _ = self;
        // Look for "id":"..." pattern after "type":"machines"
        const machines_pos = std.mem.indexOf(u8, response, "\"type\":\"machines\"") orelse
            std.mem.indexOf(u8, response, "\"type\": \"machines\"") orelse
            return null;

        // Search backwards for id
        const search_start = if (machines_pos > 100) machines_pos - 100 else 0;
        const search_slice = response[search_start..machines_pos];

        if (std.mem.lastIndexOf(u8, search_slice, "\"id\":\"")) |id_start| {
            const actual_start = search_start + id_start + 6;
            if (actual_start < response.len) {
                const end = std.mem.indexOfPos(u8, response, actual_start, "\"") orelse return null;
                return response[actual_start..end];
            }
        }

        return null;
    }

    /// Extract licensee information from response
    fn extractLicenseeInfo(self: *LicenseManager, response: []const u8) void {
        // Extract name
        if (std.mem.indexOf(u8, response, "\"name\":\"")) |start| {
            const name_start = start + 8;
            if (std.mem.indexOfPos(u8, response, name_start, "\"")) |end| {
                self.cache.licensee_name.set(response[name_start..end]);
            }
        }

        // Extract email
        if (std.mem.indexOf(u8, response, "\"email\":\"")) |start| {
            const email_start = start + 9;
            if (std.mem.indexOfPos(u8, response, email_start, "\"")) |end| {
                self.cache.licensee_email.set(response[email_start..end]);
            }
        }
    }

    /// Make HTTP POST request
    fn httpPost(self: *LicenseManager, url: []const u8, body: []const u8, response_buf: []u8) ![]const u8 {
        return self.httpRequest("POST", url, body, null, response_buf);
    }

    /// Make HTTP POST request with license key auth
    fn httpPostWithAuth(self: *LicenseManager, url: []const u8, body: []const u8, license_key: []const u8, response_buf: []u8) ![]const u8 {
        return self.httpRequest("POST", url, body, license_key, response_buf);
    }

    /// Make HTTP DELETE request
    fn httpDelete(self: *LicenseManager, url: []const u8, license_key: []const u8) bool {
        var response_buf: [1024]u8 = undefined;
        _ = self.httpRequest("DELETE", url, null, license_key, &response_buf) catch return false;
        return true;
    }

    /// Generic HTTP request using curl subprocess (more portable across Zig versions)
    fn httpRequest(
        self: *LicenseManager,
        method: []const u8,
        url: []const u8,
        body: ?[]const u8,
        license_key: ?[]const u8,
        response_buf: []u8,
    ) ![]const u8 {
        _ = self;

        // Build curl command arguments using fixed array
        var args_buf: [16][]const u8 = undefined;
        var arg_count: usize = 0;

        args_buf[arg_count] = "curl";
        arg_count += 1;
        args_buf[arg_count] = "-s"; // Silent mode
        arg_count += 1;
        args_buf[arg_count] = "-S"; // Show errors
        arg_count += 1;
        args_buf[arg_count] = "-X";
        arg_count += 1;
        args_buf[arg_count] = method;
        arg_count += 1;
        args_buf[arg_count] = "-H";
        arg_count += 1;
        args_buf[arg_count] = "Content-Type: application/vnd.api+json";
        arg_count += 1;
        args_buf[arg_count] = "-H";
        arg_count += 1;
        args_buf[arg_count] = "Accept: application/vnd.api+json";
        arg_count += 1;

        // Add authorization header if provided
        var auth_buf: [512]u8 = undefined;
        var auth_header: []const u8 = "";
        if (license_key) |key| {
            auth_header = std.fmt.bufPrint(&auth_buf, "Authorization: License {s}", .{key}) catch return error.BufferTooSmall;
            args_buf[arg_count] = "-H";
            arg_count += 1;
            args_buf[arg_count] = auth_header;
            arg_count += 1;
        }

        // Add body if provided
        if (body) |b| {
            args_buf[arg_count] = "-d";
            arg_count += 1;
            args_buf[arg_count] = b;
            arg_count += 1;
        }

        // Add URL
        args_buf[arg_count] = url;
        arg_count += 1;

        // Run curl using ChildProcess
        var child = std.process.Child.init(args_buf[0..arg_count], std.heap.page_allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch return error.SpawnFailed;

        // Read stdout directly using file read
        const stdout = child.stdout orelse return error.NoStdout;
        const response_len = stdout.readAll(response_buf) catch return error.ReadFailed;

        _ = child.wait() catch return error.WaitFailed;

        if (response_len == 0) {
            return error.NoResponse;
        }

        return response_buf[0..response_len];
    }

    /// Load license cache from disk
    fn loadCache(self: *LicenseManager) void {
        var path_buf: [512]u8 = undefined;
        const cache_path = getLicenseCachePath(&path_buf) orelse return;

        const file = std.fs.cwd().openFile(cache_path, .{}) catch return;
        defer file.close();

        var content_buf: [2048]u8 = undefined;
        const bytes_read = file.readAll(&content_buf) catch return;
        const content = content_buf[0..bytes_read];

        // Parse cache file (simple key=value format)
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "=")) |eq_pos| {
                const key = line[0..eq_pos];
                const value = line[eq_pos + 1 ..];

                if (std.mem.eql(u8, key, "license_key")) {
                    self.cache.setLicenseKey(value);
                } else if (std.mem.eql(u8, key, "machine_id")) {
                    self.cache.machine_id.set(value);
                } else if (std.mem.eql(u8, key, "fingerprint")) {
                    self.cache.machine_fingerprint.set(value);
                } else if (std.mem.eql(u8, key, "validated_at")) {
                    self.cache.validated_at = std.fmt.parseInt(i64, value, 10) catch 0;
                } else if (std.mem.eql(u8, key, "licensee_name")) {
                    self.cache.licensee_name.set(value);
                } else if (std.mem.eql(u8, key, "licensee_email")) {
                    self.cache.licensee_email.set(value);
                }
            }
        }

        // Verify fingerprint matches current machine
        const cached_fp = self.cache.machine_fingerprint.get();
        const current_fp = self.fingerprint.getFingerprint();
        if (cached_fp.len > 0 and !std.mem.eql(u8, cached_fp, current_fp)) {
            // Fingerprint mismatch - cache is from different machine
            self.cache = LicenseCache{};
            return;
        }

        // Check if cache is still valid
        if (self.cache.isValid()) {
            self.cache.status = .cached;
        }
    }

    /// Save license cache to disk
    fn saveCache(self: *LicenseManager) void {
        ensureLicenseDir();

        var path_buf: [512]u8 = undefined;
        const cache_path = getLicenseCachePath(&path_buf) orelse return;

        const file = std.fs.cwd().createFile(cache_path, .{}) catch return;
        defer file.close();

        // Write cache data
        var write_buf: [2048]u8 = undefined;
        const content = std.fmt.bufPrint(&write_buf,
            \\license_key={s}
            \\machine_id={s}
            \\fingerprint={s}
            \\validated_at={d}
            \\licensee_name={s}
            \\licensee_email={s}
            \\
        , .{
            self.cache.getLicenseKey(),
            self.cache.machine_id.get(),
            self.fingerprint.getFingerprint(),
            self.cache.validated_at,
            self.cache.licensee_name.get(),
            self.cache.licensee_email.get(),
        }) catch return;

        _ = file.writeAll(content) catch {};
    }

    /// Delete license cache from disk
    fn deleteCache(self: *LicenseManager) void {
        _ = self;
        var path_buf: [512]u8 = undefined;
        const cache_path = getLicenseCachePath(&path_buf) orelse return;
        std.fs.cwd().deleteFile(cache_path) catch {};
    }
};

// ============================================================================
// Machine Fingerprint Generation
// ============================================================================

/// Get system hostname
fn getHostname(buf: []u8) ?[]const u8 {
    // Read from /etc/hostname or use uname
    const file = std.fs.cwd().openFile("/etc/hostname", .{}) catch {
        // Try /proc/sys/kernel/hostname
        const proc_file = std.fs.cwd().openFile("/proc/sys/kernel/hostname", .{}) catch return null;
        defer proc_file.close();
        const len = proc_file.readAll(buf) catch return null;
        // Trim trailing newline
        const trimmed_len = if (len > 0 and buf[len - 1] == '\n') len - 1 else len;
        return buf[0..trimmed_len];
    };
    defer file.close();

    const len = file.readAll(buf) catch return null;
    // Trim trailing newline
    const trimmed_len = if (len > 0 and buf[len - 1] == '\n') len - 1 else len;
    return buf[0..trimmed_len];
}

/// Generate machine fingerprint from hardware identifiers
fn generateMachineFingerprint(buf: []u8) ?[]const u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});

    // Add machine-id
    if (readMachineId()) |machine_id| {
        hasher.update(machine_id);
    }

    // Add primary MAC address
    if (getPrimaryMacAddress()) |mac| {
        hasher.update(&mac);
    }

    // Add product UUID if available
    if (getProductUuid()) |uuid| {
        hasher.update(uuid);
    }

    const hash = hasher.finalResult();

    // Convert to hex string
    const hex_chars = "0123456789abcdef";
    var i: usize = 0;
    for (hash[0..16]) |byte| {
        if (i + 2 > buf.len) break;
        buf[i] = hex_chars[byte >> 4];
        buf[i + 1] = hex_chars[byte & 0xf];
        i += 2;
    }

    return buf[0..i];
}

/// Read /etc/machine-id
fn readMachineId() ?[]const u8 {
    const Static = struct {
        var buf: [64]u8 = undefined;
    };

    const file = std.fs.cwd().openFile("/etc/machine-id", .{}) catch return null;
    defer file.close();

    const len = file.readAll(&Static.buf) catch return null;
    // Trim trailing newline
    const trimmed_len = if (len > 0 and Static.buf[len - 1] == '\n') len - 1 else len;
    return Static.buf[0..trimmed_len];
}

/// Get primary network interface MAC address
fn getPrimaryMacAddress() ?[6]u8 {
    // Try common interface names
    const interfaces = [_][]const u8{ "eth0", "enp0s3", "ens33", "wlan0", "wlp2s0" };

    for (interfaces) |iface| {
        var path_buf: [128]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/sys/class/net/{s}/address", .{iface}) catch continue;

        const file = std.fs.cwd().openFile(path, .{}) catch continue;
        defer file.close();

        var addr_buf: [32]u8 = undefined;
        const len = file.readAll(&addr_buf) catch continue;
        if (len < 17) continue;

        // Parse MAC address (format: xx:xx:xx:xx:xx:xx)
        var mac: [6]u8 = undefined;
        var i: usize = 0;
        var j: usize = 0;
        while (i < 6 and j + 1 < len) {
            const high = std.fmt.charToDigit(addr_buf[j], 16) catch break;
            const low = std.fmt.charToDigit(addr_buf[j + 1], 16) catch break;
            mac[i] = (high << 4) | low;
            i += 1;
            j += 3; // Skip colon
        }

        if (i == 6) return mac;
    }

    return null;
}

/// Get product UUID from DMI
fn getProductUuid() ?[]const u8 {
    const Static = struct {
        var buf: [64]u8 = undefined;
    };

    const file = std.fs.cwd().openFile("/sys/class/dmi/id/product_uuid", .{}) catch return null;
    defer file.close();

    const len = file.readAll(&Static.buf) catch return null;
    // Trim trailing newline
    const trimmed_len = if (len > 0 and Static.buf[len - 1] == '\n') len - 1 else len;
    return Static.buf[0..trimmed_len];
}

// ============================================================================
// License Cache Path
// ============================================================================

const LICENSE_CACHE_FILENAME = "speedsx.license";

fn getLicenseCachePath(buf: []u8) ?[]const u8 {
    // Try XDG_CONFIG_HOME first, then HOME/.config
    if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg| {
        return std.fmt.bufPrint(buf, "{s}/speedsx/{s}", .{ xdg, LICENSE_CACHE_FILENAME }) catch null;
    }

    if (std.posix.getenv("HOME")) |home| {
        return std.fmt.bufPrint(buf, "{s}/.config/speedsx/{s}", .{ home, LICENSE_CACHE_FILENAME }) catch null;
    }

    // Fallback: current directory
    return std.fmt.bufPrint(buf, "./{s}", .{LICENSE_CACHE_FILENAME}) catch null;
}

fn ensureLicenseDir() void {
    var buf: [512]u8 = undefined;

    if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg| {
        const dir_path = std.fmt.bufPrint(&buf, "{s}/speedsx", .{xdg}) catch return;
        std.fs.cwd().makePath(dir_path) catch {};
        return;
    }

    if (std.posix.getenv("HOME")) |home| {
        const dir_path = std.fmt.bufPrint(&buf, "{s}/.config/speedsx", .{home}) catch return;
        std.fs.cwd().makePath(dir_path) catch {};
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "MachineFingerprint generation" {
    const fp = MachineFingerprint.generate();
    try testing.expect(fp.fingerprint.len > 0);
    try testing.expect(fp.platform.len > 0);
}

test "LicenseCache validity" {
    var cache = LicenseCache{};
    try testing.expect(!cache.isValid());

    cache.setLicenseKey("test-key");
    cache.machine_id.set("machine-123");
    cache.validated_at = std.time.timestamp();
    cache.status = .valid;

    try testing.expect(cache.isValid());
}

test "LicenseStatus messages" {
    try testing.expect(LicenseStatus.valid.isUsable());
    try testing.expect(LicenseStatus.cached.isUsable());
    try testing.expect(!LicenseStatus.invalid.isUsable());
    try testing.expect(!LicenseStatus.not_configured.isUsable());
}
