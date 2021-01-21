assert(fs.EFS, "eli.fs.extra required")

local _ok, _error = fs.safe_mkdirp("bin")
ami_assert(_ok, string.join_strings("Failed to prepare bin dir: ", _error), EXIT_APP_IO_ERROR)

local function download_and_extract(url, dst, options)
    local _tmpFile = os.tmpname()
    local _ok, _error = net.safe_download_file(url, _tmpFile, {followRedirects = true})
    if not _ok then
        fs.remove(_tmpFile)
        ami_error("Failed to download: " .. tostring(_error))
    end

    local _ok, _error = zip.safe_extract(_tmpFile, dst, options)
    fs.remove(_tmpFile)
    ami_assert(_ok, "Failed to extract: " .. tostring(_error))
end

log_info("Downloading " .. am.app.get_model("DAEMON_NAME") .. "...")
download_and_extract(am.app.get_model("DAEMON_URL"), "bin", {flattenRootDir = true, openFlags = 0})

local _ok, _files = fs.safe_read_dir("bin", { returnFullPaths = true})
ami_assert(_ok, "Failed to enumerate binaries", EXIT_APP_IO_ERROR)

for _, file in ipairs(_files) do 
    if fs.file_type(file) == 'file' then 
        local _ok, _error = fs.safe_chmod(file, "rwxrwxrwx")
        if not _ok then 
            ami_error("Failed to set file permissions for " .. file .. " - " .. _error, EXIT_APP_IO_ERROR)
        end
    end
end