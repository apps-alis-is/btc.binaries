if type(APP.model) ~= "table" then
    APP.model = {}
end

APP.model = eliUtil.merge_tables(
    APP.model,
    {
        DAEMON_URL = ""
    }
)