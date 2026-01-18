-- jsonresume.lua
-- Lua module for parsing JSON Resume data
-- Part of the jsonresume LaTeX package

local jsonresume = {}

-- Store parsed resume data
jsonresume.data = nil

-- Strict mode flag (enables validation warnings)
jsonresume.strict = false

-- Validation warnings collected during validation
jsonresume.warnings = {}

--------------------------------------------------------------------------------
-- JSON Parser (minimal implementation, no external dependencies)
--------------------------------------------------------------------------------

local json = {}

local function skip_whitespace(str, pos)
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
            pos = pos + 1
        else
            break
        end
    end
    return pos
end

local function parse_string(str, pos)
    -- Skip opening quote
    pos = pos + 1
    local result = ""
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == '"' then
            return result, pos + 1
        elseif c == '\\' then
            pos = pos + 1
            local escape = str:sub(pos, pos)
            if escape == 'n' then
                result = result .. '\n'
            elseif escape == 't' then
                result = result .. '\t'
            elseif escape == 'r' then
                result = result .. '\r'
            elseif escape == 'u' then
                -- Unicode escape: \uXXXX
                local hex = str:sub(pos + 1, pos + 4)
                local codepoint = tonumber(hex, 16)
                if codepoint then
                    if codepoint < 128 then
                        result = result .. string.char(codepoint)
                    elseif codepoint < 2048 then
                        result = result .. string.char(
                            192 + math.floor(codepoint / 64),
                            128 + (codepoint % 64)
                        )
                    else
                        result = result .. string.char(
                            224 + math.floor(codepoint / 4096),
                            128 + math.floor((codepoint % 4096) / 64),
                            128 + (codepoint % 64)
                        )
                    end
                end
                pos = pos + 4
            else
                result = result .. escape
            end
        else
            result = result .. c
        end
        pos = pos + 1
    end
    error("Unterminated string at position " .. pos)
end

local function parse_number(str, pos)
    local start = pos
    local c = str:sub(pos, pos)
    
    -- Handle negative
    if c == '-' then
        pos = pos + 1
    end
    
    -- Parse digits
    while pos <= #str do
        c = str:sub(pos, pos)
        if c:match('[0-9%.eE%+%-]') then
            pos = pos + 1
        else
            break
        end
    end
    
    local num_str = str:sub(start, pos - 1)
    local num = tonumber(num_str)
    if num == nil then
        error("Invalid number: " .. num_str)
    end
    return num, pos
end

local parse_value -- forward declaration

local function parse_array(str, pos)
    local arr = {}
    pos = pos + 1 -- skip '['
    pos = skip_whitespace(str, pos)
    
    if str:sub(pos, pos) == ']' then
        return arr, pos + 1
    end
    
    while true do
        local value
        value, pos = parse_value(str, pos)
        table.insert(arr, value)
        
        pos = skip_whitespace(str, pos)
        local c = str:sub(pos, pos)
        
        if c == ']' then
            return arr, pos + 1
        elseif c == ',' then
            pos = skip_whitespace(str, pos + 1)
        else
            error("Expected ',' or ']' in array at position " .. pos)
        end
    end
end

local function parse_object(str, pos)
    local obj = {}
    pos = pos + 1 -- skip '{'
    pos = skip_whitespace(str, pos)
    
    if str:sub(pos, pos) == '}' then
        return obj, pos + 1
    end
    
    while true do
        -- Parse key
        pos = skip_whitespace(str, pos)
        if str:sub(pos, pos) ~= '"' then
            error("Expected string key at position " .. pos)
        end
        local key
        key, pos = parse_string(str, pos)
        
        -- Skip colon
        pos = skip_whitespace(str, pos)
        if str:sub(pos, pos) ~= ':' then
            error("Expected ':' at position " .. pos)
        end
        pos = skip_whitespace(str, pos + 1)
        
        -- Parse value
        local value
        value, pos = parse_value(str, pos)
        obj[key] = value
        
        pos = skip_whitespace(str, pos)
        local c = str:sub(pos, pos)
        
        if c == '}' then
            return obj, pos + 1
        elseif c == ',' then
            pos = skip_whitespace(str, pos + 1)
        else
            error("Expected ',' or '}' in object at position " .. pos)
        end
    end
end

function parse_value(str, pos)
    pos = skip_whitespace(str, pos)
    local c = str:sub(pos, pos)
    
    if c == '"' then
        return parse_string(str, pos)
    elseif c == '{' then
        return parse_object(str, pos)
    elseif c == '[' then
        return parse_array(str, pos)
    elseif c == 't' then
        if str:sub(pos, pos + 3) == 'true' then
            return true, pos + 4
        end
        error("Invalid value at position " .. pos)
    elseif c == 'f' then
        if str:sub(pos, pos + 4) == 'false' then
            return false, pos + 5
        end
        error("Invalid value at position " .. pos)
    elseif c == 'n' then
        if str:sub(pos, pos + 3) == 'null' then
            return nil, pos + 4
        end
        error("Invalid value at position " .. pos)
    elseif c == '-' or c:match('[0-9]') then
        return parse_number(str, pos)
    else
        error("Unexpected character '" .. c .. "' at position " .. pos)
    end
end

function json.parse(str)
    if str == nil or str == "" then
        error("Empty JSON string")
    end
    local value, _ = parse_value(str, 1)
    return value
end

--------------------------------------------------------------------------------
-- JSON Resume Schema Definition
--------------------------------------------------------------------------------

-- Known top-level sections in JSON Resume schema
jsonresume.schema = {
    known_sections = {
        ["$schema"] = true,
        basics = true,
        work = true,
        volunteer = true,
        education = true,
        awards = true,
        certificates = true,
        publications = true,
        skills = true,
        languages = true,
        interests = true,
        references = true,
        projects = true,
        meta = true
    },
    
    -- Required fields per section
    required_fields = {
        basics = {"name"},
    },
    
    -- Expected field types per section
    field_types = {
        basics = {
            name = "string",
            label = "string",
            image = "string",
            email = "string",
            phone = "string",
            url = "string",
            summary = "string",
            location = "object",
            profiles = "array"
        },
        work = {
            name = "string",
            position = "string",
            url = "string",
            startDate = "string",
            endDate = "string",
            summary = "string",
            highlights = "array",
            location = "string"
        },
        volunteer = {
            organization = "string",
            position = "string",
            url = "string",
            startDate = "string",
            endDate = "string",
            summary = "string",
            highlights = "array"
        },
        education = {
            institution = "string",
            url = "string",
            area = "string",
            studyType = "string",
            startDate = "string",
            endDate = "string",
            score = "string",
            courses = "array"
        },
        awards = {
            title = "string",
            date = "string",
            awarder = "string",
            summary = "string"
        },
        certificates = {
            name = "string",
            date = "string",
            issuer = "string",
            url = "string"
        },
        publications = {
            name = "string",
            publisher = "string",
            releaseDate = "string",
            url = "string",
            summary = "string"
        },
        skills = {
            name = "string",
            level = "string",
            keywords = "array"
        },
        languages = {
            language = "string",
            fluency = "string"
        },
        interests = {
            name = "string",
            keywords = "array"
        },
        references = {
            name = "string",
            reference = "string"
        },
        projects = {
            name = "string",
            description = "string",
            highlights = "array",
            keywords = "array",
            startDate = "string",
            endDate = "string",
            url = "string",
            roles = "array",
            entity = "string",
            type = "string"
        }
    }
}

--------------------------------------------------------------------------------
-- Validation Functions
--------------------------------------------------------------------------------

-- Emit a warning (LaTeX package warning)
function jsonresume.warn(message)
    table.insert(jsonresume.warnings, message)
    if jsonresume.strict then
        tex.sprint("\\PackageWarning{jsonresume}{" .. message:gsub("\\", "\\\\"):gsub("{", "\\{"):gsub("}", "\\}") .. "}")
    end
end

-- Clear all warnings
function jsonresume.clear_warnings()
    jsonresume.warnings = {}
end

-- Check if a string matches date format (YYYY, YYYY-MM, or YYYY-MM-DD)
local function is_valid_date(str)
    if str == nil or str == "" then
        return true
    end
    if str:match("^%d%d%d%d$") then return true end
    if str:match("^%d%d%d%d%-%d%d$") then return true end
    if str:match("^%d%d%d%d%-%d%d%-%d%d$") then return true end
    return false
end

-- Check if a string looks like a URL
local function is_valid_url(str)
    if str == nil or str == "" then
        return true
    end
    if str:match("^https?://") or str:match("^mailto:") or str:match("^tel:") then
        return true
    end
    return false
end

-- Get Lua type as schema type
local function get_schema_type(value)
    local t = type(value)
    if t == "table" then
        if #value > 0 or next(value) == nil then
            return "array"
        else
            return "object"
        end
    end
    return t
end

-- Validate a single entry against expected field types
local function validate_entry(entry, field_types, section_name, index)
    if type(entry) ~= "table" then
        return
    end
    
    for field, value in pairs(entry) do
        local expected_type = field_types[field]
        if expected_type then
            local actual_type = get_schema_type(value)
            if actual_type ~= expected_type and value ~= nil then
                jsonresume.warn(section_name .. "[" .. index .. "]." .. field .. ": expected " .. expected_type .. ", got " .. actual_type)
            end
        end
        
        -- Validate date fields
        if field:match("Date$") or field == "date" then
            if not is_valid_date(value) then
                jsonresume.warn(section_name .. "[" .. index .. "]." .. field .. ": invalid date format '" .. tostring(value) .. "' (expected YYYY, YYYY-MM, or YYYY-MM-DD)")
            end
        end
        
        -- Validate URL fields
        if field == "url" or field == "image" then
            if not is_valid_url(value) then
                jsonresume.warn(section_name .. "[" .. index .. "]." .. field .. ": invalid URL format '" .. tostring(value) .. "'")
            end
        end
    end
end

-- Main validation function
function jsonresume.validate()
    jsonresume.clear_warnings()
    
    if jsonresume.data == nil then
        jsonresume.warn("No resume data loaded")
        return false
    end
    
    local data = jsonresume.data
    local valid = true
    
    -- Check for unknown top-level sections
    for key, _ in pairs(data) do
        if not jsonresume.schema.known_sections[key] then
            jsonresume.warn("Unknown top-level section: " .. tostring(key))
        end
    end
    
    -- Check required fields
    for section, required in pairs(jsonresume.schema.required_fields) do
        local section_data = data[section]
        if section_data then
            for _, field in ipairs(required) do
                if section_data[field] == nil or section_data[field] == "" then
                    jsonresume.warn("Missing required field: " .. section .. "." .. field)
                    valid = false
                end
            end
        end
    end
    
    -- Validate basics section (special case - not an array)
    if data.basics then
        local field_types = jsonresume.schema.field_types.basics
        for field, value in pairs(data.basics) do
            local expected_type = field_types[field]
            if expected_type then
                local actual_type = get_schema_type(value)
                if actual_type ~= expected_type and value ~= nil then
                    jsonresume.warn("basics." .. field .. ": expected " .. expected_type .. ", got " .. actual_type)
                end
            end
            
            if field == "url" or field == "image" then
                if not is_valid_url(value) then
                    jsonresume.warn("basics." .. field .. ": invalid URL format '" .. tostring(value) .. "'")
                end
            end
        end
        
        -- Validate profiles
        if data.basics.profiles then
            for i, profile in ipairs(data.basics.profiles) do
                if profile.url and not is_valid_url(profile.url) then
                    jsonresume.warn("basics.profiles[" .. i .. "].url: invalid URL format")
                end
            end
        end
        
        -- Validate location
        if data.basics.location and type(data.basics.location) ~= "table" then
            jsonresume.warn("basics.location: expected object, got " .. type(data.basics.location))
        end
    end
    
    -- Validate array sections
    local array_sections = {"work", "volunteer", "education", "awards", "certificates", 
                           "publications", "skills", "languages", "interests", "references", "projects"}
    
    for _, section in ipairs(array_sections) do
        local section_data = data[section]
        if section_data then
            if type(section_data) ~= "table" then
                jsonresume.warn(section .. ": expected array, got " .. type(section_data))
            else
                local field_types = jsonresume.schema.field_types[section]
                if field_types then
                    for i, entry in ipairs(section_data) do
                        validate_entry(entry, field_types, section, i)
                    end
                end
            end
        end
    end
    
    return valid and #jsonresume.warnings == 0
end

-- Get validation summary
function jsonresume.get_validation_summary()
    if #jsonresume.warnings == 0 then
        return "Resume validated successfully - no issues found"
    else
        return "Resume validation found " .. #jsonresume.warnings .. " issue(s)"
    end
end

-- Get warning count
function jsonresume.get_warning_count()
    return #jsonresume.warnings
end

--------------------------------------------------------------------------------
-- File and URL Loading
--------------------------------------------------------------------------------

-- Load JSON from a local file
function jsonresume.load_file(path)
    local file, err = io.open(path, "r")
    if not file then
        error("Cannot open file: " .. path .. " (" .. (err or "unknown error") .. ")")
    end
    local content = file:read("*all")
    file:close()
    
    jsonresume.data = json.parse(content)
    
    -- Auto-validate in strict mode
    if jsonresume.strict then
        jsonresume.validate()
    end
    
    return jsonresume.data
end

-- Load JSON from a URL using curl
function jsonresume.load_url(url)
    -- Create a temporary file for the output
    local tmpfile = os.tmpname()
    
    -- Use curl to fetch the URL
    local cmd = string.format('curl -sL "%s" -o "%s" 2>/dev/null', url, tmpfile)
    local result = os.execute(cmd)
    
    if result ~= 0 and result ~= true then
        os.remove(tmpfile)
        error("Failed to fetch URL: " .. url)
    end
    
    -- Read the temporary file
    local file, err = io.open(tmpfile, "r")
    if not file then
        os.remove(tmpfile)
        error("Cannot read downloaded content: " .. (err or "unknown error"))
    end
    
    local content = file:read("*all")
    file:close()
    os.remove(tmpfile)
    
    if content == nil or content == "" then
        error("Empty response from URL: " .. url)
    end
    
    jsonresume.data = json.parse(content)
    
    -- Auto-validate in strict mode
    if jsonresume.strict then
        jsonresume.validate()
    end
    
    return jsonresume.data
end

--------------------------------------------------------------------------------
-- Data Access Helpers
--------------------------------------------------------------------------------

-- Get a nested value using dot notation (e.g., "basics.name")
function jsonresume.get(path)
    if jsonresume.data == nil then
        return nil
    end
    
    local current = jsonresume.data
    for part in path:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        -- Handle array index
        local index = tonumber(part)
        if index then
            current = current[index]
        else
            current = current[part]
        end
        if current == nil then
            return nil
        end
    end
    return current
end

-- Get a value with a default fallback
function jsonresume.get_or(path, default)
    local value = jsonresume.get(path)
    if value == nil then
        return default
    end
    return value
end

-- Check if a path exists and has a value
function jsonresume.has(path)
    return jsonresume.get(path) ~= nil
end

-- Get the length of an array at path
function jsonresume.count(path)
    local arr = jsonresume.get(path)
    if type(arr) ~= "table" then
        return 0
    end
    return #arr
end

--------------------------------------------------------------------------------
-- LaTeX Output Helpers
--------------------------------------------------------------------------------

-- Escape special LaTeX characters
function jsonresume.escape_latex(str)
    if str == nil then
        return ""
    end
    str = tostring(str)
    -- Order matters: & must be first, then others
    str = str:gsub("\\", "\\textbackslash{}")
    str = str:gsub("&", "\\&")
    str = str:gsub("%%", "\\%%")
    str = str:gsub("%$", "\\$")
    str = str:gsub("#", "\\#")
    str = str:gsub("_", "\\_")
    str = str:gsub("{", "\\{")
    str = str:gsub("}", "\\}")
    str = str:gsub("~", "\\textasciitilde{}")
    str = str:gsub("%^", "\\textasciicircum{}")
    return str
end

-- Get an escaped value
function jsonresume.get_escaped(path)
    local value = jsonresume.get(path)
    if value == nil then
        return ""
    end
    return jsonresume.escape_latex(value)
end

-- Format a date range (startDate - endDate or startDate - Present)
function jsonresume.format_date_range(start_date, end_date)
    local start_str = start_date or ""
    local end_str = end_date or "Present"
    
    -- Extract year and month if in YYYY-MM-DD or YYYY-MM format
    local function format_date(d)
        if d == "" or d == "Present" then
            return d
        end
        local year, month = d:match("^(%d%d%d%d)%-?(%d?%d?)")
        if year then
            if month and month ~= "" then
                local months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
                local m = tonumber(month)
                if m and months[m] then
                    return months[m] .. " " .. year
                end
            end
            return year
        end
        return d
    end
    
    return format_date(start_str) .. " -- " .. format_date(end_str)
end

--------------------------------------------------------------------------------
-- LaTeX Rendering Functions
--------------------------------------------------------------------------------

-- Render basics section (name, contact, summary)
function jsonresume.render_basics()
    local basics = jsonresume.get("basics")
    if not basics then return end
    
    -- Name (large, centered)
    local name = jsonresume.get_escaped("basics.name")
    if name ~= "" then
        tex.sprint("\\begin{center}")
        tex.sprint("{\\LARGE\\bfseries " .. name .. "}")
        
        -- Label/title
        local label = jsonresume.get_escaped("basics.label")
        if label ~= "" then
            tex.sprint("\\\\[0.2em]{\\large " .. label .. "}")
        end
        
        -- Contact line: email | phone | url | location
        local contacts = {}
        
        local email = jsonresume.get("basics.email")
        if email then
            table.insert(contacts, "\\href{mailto:" .. email .. "}{" .. jsonresume.escape_latex(email) .. "}")
        end
        
        local phone = jsonresume.get("basics.phone")
        if phone then
            table.insert(contacts, jsonresume.escape_latex(phone))
        end
        
        local url = jsonresume.get("basics.url")
        if url then
            table.insert(contacts, "\\href{" .. url .. "}{" .. jsonresume.escape_latex(url:gsub("^https?://", "")) .. "}")
        end
        
        local location = jsonresume.get("basics.location")
        if location then
            local loc_parts = {}
            if location.city then table.insert(loc_parts, jsonresume.escape_latex(location.city)) end
            if location.region then table.insert(loc_parts, jsonresume.escape_latex(location.region)) end
            if location.countryCode then table.insert(loc_parts, jsonresume.escape_latex(location.countryCode)) end
            if #loc_parts > 0 then
                table.insert(contacts, table.concat(loc_parts, ", "))
            end
        end
        
        if #contacts > 0 then
            tex.sprint("\\\\[0.3em]")
            tex.sprint(table.concat(contacts, " \\textbar\\ "))
        end
        
        -- Social profiles
        local profiles = jsonresume.get("basics.profiles")
        if profiles and #profiles > 0 then
            local profile_links = {}
            for _, p in ipairs(profiles) do
                local purl = p.url or ""
                local pnetwork = p.network or ""
                local pusername = p.username or ""
                if purl ~= "" then
                    local display = pusername ~= "" and pusername or pnetwork
                    table.insert(profile_links, "\\href{" .. purl .. "}{" .. jsonresume.escape_latex(display) .. "}")
                elseif pusername ~= "" then
                    table.insert(profile_links, jsonresume.escape_latex(pnetwork .. ": " .. pusername))
                end
            end
            if #profile_links > 0 then
                tex.sprint("\\\\[0.2em]")
                tex.sprint(table.concat(profile_links, " \\textbar\\ "))
            end
        end
        
        tex.sprint("\\end{center}")
    end
    
    -- Summary
    local summary = jsonresume.get_escaped("basics.summary")
    if summary ~= "" then
        tex.sprint("\\vspace{0.5em}")
        tex.sprint("\\noindent " .. summary)
        tex.sprint("\\vspace{0.3em}")
    end
end

-- Render work experience section
function jsonresume.render_work(title)
    local work = jsonresume.get("work")
    if not work or #work == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, job in ipairs(work) do
        -- Position and company
        local position = jsonresume.get_escaped("work." .. i .. ".position")
        local company = jsonresume.get("work." .. i .. ".name")
        local companyUrl = jsonresume.get("work." .. i .. ".url")
        local companyDisplay = ""
        if company then
            if companyUrl then
                companyDisplay = "\\href{" .. companyUrl .. "}{" .. jsonresume.escape_latex(company) .. "}"
            else
                companyDisplay = jsonresume.escape_latex(company)
            end
        end
        
        -- Location
        local location = jsonresume.get_escaped("work." .. i .. ".location") or ""
        
        -- Dates
        local startDate = jsonresume.get("work." .. i .. ".startDate") or ""
        local endDate = jsonresume.get("work." .. i .. ".endDate")
        local dateRange = jsonresume.format_date_range(startDate, endDate)
        
        tex.sprint("\\jrentryheader{" .. position .. "}{" .. companyDisplay .. "}{" .. location .. "}{" .. dateRange .. "}")
        
        -- Summary
        local summary = jsonresume.get_escaped("work." .. i .. ".summary")
        if summary ~= "" then
            tex.sprint("\\noindent " .. summary .. "\\par")
        end
        
        -- Highlights
        local highlights = jsonresume.get("work." .. i .. ".highlights")
        if highlights and #highlights > 0 then
            tex.sprint("\\begin{itemize}[nosep,leftmargin=1.5em]")
            for _, h in ipairs(highlights) do
                tex.sprint("\\item " .. jsonresume.escape_latex(h))
            end
            tex.sprint("\\end{itemize}")
        end
        
        if i < #work then
            tex.sprint("\\vspace{0.5em}")
        end
    end
end

-- Render education section
function jsonresume.render_education(title)
    local edu = jsonresume.get("education")
    if not edu or #edu == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, entry in ipairs(edu) do
        -- Degree and field
        local studyType = jsonresume.get_escaped("education." .. i .. ".studyType")
        local area = jsonresume.get_escaped("education." .. i .. ".area")
        local degree_title = ""
        if studyType ~= "" and area ~= "" then
            degree_title = studyType .. " in " .. area
        elseif studyType ~= "" then
            degree_title = studyType
        elseif area ~= "" then
            degree_title = area
        end
        
        -- Institution
        local institution = jsonresume.get("education." .. i .. ".institution")
        local instUrl = jsonresume.get("education." .. i .. ".url")
        local instDisplay = ""
        if institution then
            if instUrl then
                instDisplay = "\\href{" .. instUrl .. "}{" .. jsonresume.escape_latex(institution) .. "}"
            else
                instDisplay = jsonresume.escape_latex(institution)
            end
        end
        
        -- Dates
        local startDate = jsonresume.get("education." .. i .. ".startDate") or ""
        local endDate = jsonresume.get("education." .. i .. ".endDate")
        local dateRange = jsonresume.format_date_range(startDate, endDate)
        
        tex.sprint("\\jrentryheader{" .. degree_title .. "}{" .. instDisplay .. "}{}{" .. dateRange .. "}")
        
        -- Score/GPA
        local score = jsonresume.get_escaped("education." .. i .. ".score")
        if score ~= "" then
            tex.sprint("\\noindent GPA: " .. score .. "\\par")
        end
        
        -- Courses
        local courses = jsonresume.get("education." .. i .. ".courses")
        if courses and #courses > 0 then
            local escaped_courses = {}
            for _, c in ipairs(courses) do
                table.insert(escaped_courses, jsonresume.escape_latex(c))
            end
            tex.sprint("\\noindent\\textit{Relevant coursework:} " .. table.concat(escaped_courses, ", ") .. "\\par")
        end
        
        if i < #edu then
            tex.sprint("\\vspace{0.5em}")
        end
    end
end

-- Render skills section
function jsonresume.render_skills(title)
    local skills = jsonresume.get("skills")
    if not skills or #skills == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    local skill_lines = {}
    for i, skill in ipairs(skills) do
        local name = jsonresume.get_escaped("skills." .. i .. ".name")
        local keywords = jsonresume.get("skills." .. i .. ".keywords")
        
        if name ~= "" then
            local line = "\\textbf{" .. name .. "}"
            if keywords and #keywords > 0 then
                local escaped_keywords = {}
                for _, k in ipairs(keywords) do
                    table.insert(escaped_keywords, jsonresume.escape_latex(k))
                end
                line = line .. ": " .. table.concat(escaped_keywords, ", ")
            end
            table.insert(skill_lines, line)
        end
    end
    
    if #skill_lines > 0 then
        tex.sprint("\\begin{itemize}[nosep,leftmargin=1.5em]")
        for _, line in ipairs(skill_lines) do
            tex.sprint("\\item " .. line)
        end
        tex.sprint("\\end{itemize}")
    end
end

-- Render volunteer section
function jsonresume.render_volunteer(title)
    local volunteer = jsonresume.get("volunteer")
    if not volunteer or #volunteer == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, entry in ipairs(volunteer) do
        local position = jsonresume.get_escaped("volunteer." .. i .. ".position")
        local organization = jsonresume.get("volunteer." .. i .. ".organization")
        local orgUrl = jsonresume.get("volunteer." .. i .. ".url")
        local orgDisplay = ""
        if organization then
            if orgUrl then
                orgDisplay = "\\href{" .. orgUrl .. "}{" .. jsonresume.escape_latex(organization) .. "}"
            else
                orgDisplay = jsonresume.escape_latex(organization)
            end
        end
        
        local startDate = jsonresume.get("volunteer." .. i .. ".startDate") or ""
        local endDate = jsonresume.get("volunteer." .. i .. ".endDate")
        local dateRange = jsonresume.format_date_range(startDate, endDate)
        
        tex.sprint("\\jrentryheader{" .. position .. "}{" .. orgDisplay .. "}{}{" .. dateRange .. "}")
        
        local summary = jsonresume.get_escaped("volunteer." .. i .. ".summary")
        if summary ~= "" then
            tex.sprint("\\noindent " .. summary .. "\\par")
        end
        
        local highlights = jsonresume.get("volunteer." .. i .. ".highlights")
        if highlights and #highlights > 0 then
            tex.sprint("\\begin{itemize}[nosep,leftmargin=1.5em]")
            for _, h in ipairs(highlights) do
                tex.sprint("\\item " .. jsonresume.escape_latex(h))
            end
            tex.sprint("\\end{itemize}")
        end
        
        if i < #volunteer then
            tex.sprint("\\vspace{0.5em}")
        end
    end
end

-- Render awards section
function jsonresume.render_awards(title)
    local awards = jsonresume.get("awards")
    if not awards or #awards == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, award in ipairs(awards) do
        local award_title = jsonresume.get_escaped("awards." .. i .. ".title")
        local awarder = jsonresume.get_escaped("awards." .. i .. ".awarder")
        local date = jsonresume.get("awards." .. i .. ".date") or ""
        
        local formatted_date = ""
        if date ~= "" then
            local year, month = date:match("^(%d%d%d%d)%-?(%d?%d?)")
            if year then
                if month and month ~= "" then
                    local months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
                    local m = tonumber(month)
                    if m and months[m] then
                        formatted_date = months[m] .. " " .. year
                    else
                        formatted_date = year
                    end
                else
                    formatted_date = year
                end
            else
                formatted_date = date
            end
        end
        
        tex.sprint("\\noindent\\textbf{" .. award_title .. "}")
        if awarder ~= "" then
            tex.sprint(" -- " .. awarder)
        end
        if formatted_date ~= "" then
            tex.sprint("\\hfill\\textit{" .. formatted_date .. "}")
        end
        tex.sprint("\\par")
        
        local summary = jsonresume.get_escaped("awards." .. i .. ".summary")
        if summary ~= "" then
            tex.sprint("\\noindent " .. summary .. "\\par")
        end
        
        if i < #awards then
            tex.sprint("\\vspace{0.3em}")
        end
    end
end

-- Render certificates section
function jsonresume.render_certificates(title)
    local certs = jsonresume.get("certificates")
    if not certs or #certs == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, cert in ipairs(certs) do
        local cert_name = jsonresume.get_escaped("certificates." .. i .. ".name")
        local issuer = jsonresume.get_escaped("certificates." .. i .. ".issuer")
        local date = jsonresume.get("certificates." .. i .. ".date") or ""
        local certUrl = jsonresume.get("certificates." .. i .. ".url")
        
        local formatted_date = ""
        if date ~= "" then
            local year, month = date:match("^(%d%d%d%d)%-?(%d?%d?)")
            if year then
                if month and month ~= "" then
                    local months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
                    local m = tonumber(month)
                    if m and months[m] then
                        formatted_date = months[m] .. " " .. year
                    else
                        formatted_date = year
                    end
                else
                    formatted_date = year
                end
            else
                formatted_date = date
            end
        end
        
        tex.sprint("\\noindent")
        if certUrl then
            tex.sprint("\\href{" .. certUrl .. "}{\\textbf{" .. cert_name .. "}}")
        else
            tex.sprint("\\textbf{" .. cert_name .. "}")
        end
        if issuer ~= "" then
            tex.sprint(" -- " .. issuer)
        end
        if formatted_date ~= "" then
            tex.sprint("\\hfill\\textit{" .. formatted_date .. "}")
        end
        tex.sprint("\\par")
        
        if i < #certs then
            tex.sprint("\\vspace{0.3em}")
        end
    end
end

-- Render publications section
function jsonresume.render_publications(title)
    local pubs = jsonresume.get("publications")
    if not pubs or #pubs == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, pub in ipairs(pubs) do
        local pub_name = jsonresume.get_escaped("publications." .. i .. ".name")
        local publisher = jsonresume.get_escaped("publications." .. i .. ".publisher")
        local releaseDate = jsonresume.get("publications." .. i .. ".releaseDate") or ""
        local pubUrl = jsonresume.get("publications." .. i .. ".url")
        
        local formatted_date = ""
        if releaseDate ~= "" then
            local year, month = releaseDate:match("^(%d%d%d%d)%-?(%d?%d?)")
            if year then
                if month and month ~= "" then
                    local months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
                    local m = tonumber(month)
                    if m and months[m] then
                        formatted_date = months[m] .. " " .. year
                    else
                        formatted_date = year
                    end
                else
                    formatted_date = year
                end
            else
                formatted_date = releaseDate
            end
        end
        
        tex.sprint("\\noindent")
        if pubUrl then
            tex.sprint("\\href{" .. pubUrl .. "}{\\textbf{" .. pub_name .. "}}")
        else
            tex.sprint("\\textbf{" .. pub_name .. "}")
        end
        if publisher ~= "" then
            tex.sprint(" -- " .. publisher)
        end
        if formatted_date ~= "" then
            tex.sprint("\\hfill\\textit{" .. formatted_date .. "}")
        end
        tex.sprint("\\par")
        
        local summary = jsonresume.get_escaped("publications." .. i .. ".summary")
        if summary ~= "" then
            tex.sprint("\\noindent " .. summary .. "\\par")
        end
        
        if i < #pubs then
            tex.sprint("\\vspace{0.3em}")
        end
    end
end

-- Render languages section
function jsonresume.render_languages(title)
    local languages = jsonresume.get("languages")
    if not languages or #languages == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    local lang_items = {}
    for i, lang in ipairs(languages) do
        local language = jsonresume.get_escaped("languages." .. i .. ".language")
        local fluency = jsonresume.get_escaped("languages." .. i .. ".fluency")
        
        if language ~= "" then
            local item = "\\textbf{" .. language .. "}"
            if fluency ~= "" then
                item = item .. " (" .. fluency .. ")"
            end
            table.insert(lang_items, item)
        end
    end
    
    if #lang_items > 0 then
        tex.sprint("\\noindent " .. table.concat(lang_items, " \\textbar\\ ") .. "\\par")
    end
end

-- Render interests section
function jsonresume.render_interests(title)
    local interests = jsonresume.get("interests")
    if not interests or #interests == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, interest in ipairs(interests) do
        local name = jsonresume.get_escaped("interests." .. i .. ".name")
        local keywords = jsonresume.get("interests." .. i .. ".keywords")
        
        if name ~= "" then
            tex.sprint("\\noindent\\textbf{" .. name .. "}")
            if keywords and #keywords > 0 then
                local escaped_keywords = {}
                for _, k in ipairs(keywords) do
                    table.insert(escaped_keywords, jsonresume.escape_latex(k))
                end
                tex.sprint(": " .. table.concat(escaped_keywords, ", "))
            end
            tex.sprint("\\par")
        end
        
        if i < #interests then
            tex.sprint("\\vspace{0.2em}")
        end
    end
end

-- Render references section
function jsonresume.render_references(title)
    local refs = jsonresume.get("references")
    if not refs or #refs == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, ref in ipairs(refs) do
        local name = jsonresume.get_escaped("references." .. i .. ".name")
        local reference = jsonresume.get_escaped("references." .. i .. ".reference")
        
        if name ~= "" then
            tex.sprint("\\noindent\\textbf{" .. name .. "}")
            tex.sprint("\\par")
        end
        
        if reference ~= "" then
            tex.sprint("\\noindent\\textit{``" .. reference .. "''}")
            tex.sprint("\\par")
        end
        
        if i < #refs then
            tex.sprint("\\vspace{0.5em}")
        end
    end
end

-- Render projects section
function jsonresume.render_projects(title)
    local projects = jsonresume.get("projects")
    if not projects or #projects == 0 then return end
    
    tex.sprint("\\jrsectionheader{" .. title .. "}")
    
    for i, project in ipairs(projects) do
        local proj_name = jsonresume.get_escaped("projects." .. i .. ".name")
        local projUrl = jsonresume.get("projects." .. i .. ".url")
        local description = jsonresume.get_escaped("projects." .. i .. ".description")
        
        local startDate = jsonresume.get("projects." .. i .. ".startDate") or ""
        local endDate = jsonresume.get("projects." .. i .. ".endDate")
        local dateRange = ""
        if startDate ~= "" then
            dateRange = jsonresume.format_date_range(startDate, endDate)
        end
        
        tex.sprint("\\noindent")
        if projUrl then
            tex.sprint("\\href{" .. projUrl .. "}{\\textbf{" .. proj_name .. "}}")
        else
            tex.sprint("\\textbf{" .. proj_name .. "}")
        end
        if dateRange ~= "" then
            tex.sprint("\\hfill\\textit{" .. dateRange .. "}")
        end
        tex.sprint("\\par")
        
        if description ~= "" then
            tex.sprint("\\noindent " .. description .. "\\par")
        end
        
        local highlights = jsonresume.get("projects." .. i .. ".highlights")
        if highlights and #highlights > 0 then
            tex.sprint("\\begin{itemize}[nosep,leftmargin=1.5em]")
            for _, h in ipairs(highlights) do
                tex.sprint("\\item " .. jsonresume.escape_latex(h))
            end
            tex.sprint("\\end{itemize}")
        end
        
        local keywords = jsonresume.get("projects." .. i .. ".keywords")
        if keywords and #keywords > 0 then
            local escaped_keywords = {}
            for _, k in ipairs(keywords) do
                table.insert(escaped_keywords, jsonresume.escape_latex(k))
            end
            tex.sprint("\\noindent\\textit{Technologies:} " .. table.concat(escaped_keywords, ", ") .. "\\par")
        end
        
        if i < #projects then
            tex.sprint("\\vspace{0.5em}")
        end
    end
end

return jsonresume
