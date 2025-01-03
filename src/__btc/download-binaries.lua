assert(fs.EFS, "eli.fs.extra required")

local _ok, _error = fs.safe_mkdirp("bin")
ami_assert(_ok, string.join_strings("Failed to prepare bin dir: ", _error), EXIT_APP_IO_ERROR)

local extract_archive_fns = {
    zip = function(src, dst, options)
        local _ok, _error = zip.safe_extract(src, dst, options)
        fs.remove(src)
        ami_assert(_ok, "Failed to extract: " .. tostring(_error))
    end,
    ["tar"] = function(src, dst, options)
        local _ok, _error = tar.safe_extract(src, dst, options)
        fs.remove(src)
        ami_assert(_ok, "Failed to extract: " .. tostring(_error))
    end,
    ["tar.gz"] = function(src, dst, options)
        local _tmp_file = os.tmpname()
        local _ok, _error = lz.safe_extract(src, _tmp_file)
        fs.remove(src)
        if not _ok then
            fs.remove(_tmp_file)
            ami_error("Failed to extract: " .. tostring(_error))
        end

        local _ok, _error = tar.safe_extract(_tmp_file, dst, options)
        fs.remove(_tmp_file)
        ami_assert(_ok, "Failed to extract: " .. tostring(_error))
    end
}

local function download_and_extract(url, dst, options)
    local _tmp_file = os.tmpname()
    local _ok, _error = net.safe_download_file(url, _tmp_file, { follow_redirects = true })
    if not _ok then
        fs.remove(_tmp_file)
        ami_error("Failed to download: " .. tostring(_error))
    end

    local _archive_kind = am.app.get_model("DAEMON_ARCHIVE_KIND", "zip")
    local _extract_fn = extract_archive_fns[_archive_kind]
    ami_assert(type(_extract_fn) == "function", "Unsupported daemon archive kind " .. tostring(_archive_kind) .. "!")
    _extract_fn(_tmp_file, dst, options)
end

log_info("Downloading " .. am.app.get_model("DAEMON_NAME") .. "...")
download_and_extract(am.app.get_model("DAEMON_URL"), "bin", { flatten_root_dir = true, open_flags = 0 })

local _ok, _files = fs.safe_read_dir("bin", { return_full_paths = true }) --[[@as DirEntry]]
ami_assert(_ok, "Failed to enumerate binaries", EXIT_APP_IO_ERROR)

for _, file in ipairs(_files) do
    if fs.file_type(file) == 'file' then
        local _ok, _error = fs.safe_chmod(file, "rwxrwxrwx")
        if not _ok then
            ami_error("Failed to set file permissions for " .. file .. " - " .. _error, EXIT_APP_IO_ERROR)
        end
    end
end
