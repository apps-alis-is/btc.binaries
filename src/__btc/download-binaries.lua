assert(fs.EFS, "eli.fs.extra required")

local ok, err = fs.mkdirp("bin")
ami_assert(ok, string.join_strings("Failed to prepare bin dir: ", err), EXIT_APP_IO_ERROR)

local extract_archive_fns = {
    zip = function(src, dst, options)
        local ok, err = zip.extract(src, dst, options)
        fs.remove(src)
        ami_assert(ok, "Failed to extract: " .. tostring(err))
    end,
    ["tar"] = function(src, dst, options)
        local ok, err = tar.extract(src, dst, options)
        fs.remove(src)
        ami_assert(ok, "Failed to extract: " .. tostring(err))
    end,
    ["tar.gz"] = function(src, dst, options)
        local tmp_file = os.tmpname()
        local ok, err = lz.extract(src, tmp_file)
        fs.remove(src)
        if not ok then
            fs.remove(tmp_file)
            ami_error("Failed to extract: " .. tostring(err))
        end

        local ok, err = tar.extract(tmp_file, dst, options)
        fs.remove(tmp_file)
        ami_assert(ok, "Failed to extract: " .. tostring(err))
    end
}

local function download_and_extract(url, dst, options)
    local tmp_file = os.tmpname()
    local ok, err = net.download_file(url, tmp_file, { follow_redirects = true })
    if not ok then
        fs.remove(tmp_file)
        ami_error("Failed to download: " .. tostring(err))
    end

    local archive_kind = am.app.get_model("DAEMON_ARCHIVE_KIND", "zip")
    local _extract_fn = extract_archive_fns[archive_kind]
    ami_assert(type(_extract_fn) == "function", "Unsupported daemon archive kind " .. tostring(archive_kind) .. "!")
    _extract_fn(tmp_file, dst, options)
end

log_info("Downloading " .. am.app.get_model("DAEMON_NAME") .. "...")
download_and_extract(am.app.get_model("DAEMON_URL"), "bin", { flatten_root_dir = true, open_flags = 0 })

local files, err = fs.read_dir("bin", { return_full_paths = true }) --[[@as DirEntry]]
ami_assert(files, "Failed to enumerate binaries", EXIT_APP_IO_ERROR)

for _, file in ipairs(files) do
    if fs.file_type(file) == 'file' then
        local ok, err = fs.chmod(file, "rwxrwxrwx")
        if not ok then
            ami_error("Failed to set file permissions for " .. file .. " - " .. err, EXIT_APP_IO_ERROR)
        end
    end
end
