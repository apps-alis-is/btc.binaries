local _exString = require "eli.extensions.string"

assert(eliFs.EFS, "eli.fs.extra required")

local _ok, _error = eliFs.safe_mkdirp("bin")
ami_assert(_ok, _exString.join_strings("Failed to prepare bin dir: ", _error), EXIT_APP_IO_ERROR)

local function download_and_extract(url, dst, options)
    local _tmpFile = os.tmpname()
    local _ok, _error = eliNet.safe_download_file(url, _tmpFile, {followRedirects = true})
    if not _ok then
        eliFs.remove(_tmpFile)
        ami_error("Failed to download: " .. tostring(_error), EXIT_APP_DOWNLOAD_ERROR)
    end

    local _ok, _error = eliZip.safe_extract(_tmpFile, dst, options)
    eliFs.remove(_tmpFile)
    ami_assert(_ok, "Failed to extract: " .. tostring(_error), EXIT_APP_DOWNLOAD_ERROR)
end

log_info("Downloading " .. APP.model.DAEMON_NAME .. "...")
download_and_extract(APP.model.DAEMON_URL, "bin", {flattenRootDir = true, openFlags = 0})

local _ok, _files = eliFs.safe_read_dir("bin", { returnFullPaths = true})
ami_assert(_ok, "Failed to enumerate binaries", EXIT_APP_IO_ERROR)

for _, file in ipairs(_files) do 
    if eliFs.file_type(file) == 'file' then 
        local _ok, _error = eliFs.safe_chmod(file, "rwxrwxrwx")
        if not _ok then 
            ami_error("Failed to set file permissions for " .. file .. " - " .. _error, EXIT_APP_IO_ERROR)
        end
    end
end