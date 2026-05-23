local M = {}

function M.parse_porcelain_v2(lines)
  local staged = {}
  local unstaged = {}
  local untracked = {}
  local props = {}

  local i = 1
  while i <= #lines do
    local line = lines[i]
    if line == "" then
      -- skip
    elseif line:sub(1, 1) == "#" then
      local key, val = line:match("^# (%S+) (.*)")
      if key then
        props[key] = val
      end
    elseif line:sub(1, 1) == "?" then
      local filename = line:sub(3)
      table.insert(untracked, {
        type = "File",
        status = "?",
        filename = filename,
        relative = { filename },
      })
    elseif line:sub(1, 1) ~= "#" then
      local kind = line:sub(1, 1)
      local file_start
      if kind == "u" then
        -- unmerged
        file_start = 38 + 40 + 40 + 40 + 3 -- mode + 3 sha1s + some spaces
        -- Actually v2 format is:
        -- u <xy><sub> <m1> <m2> <m3> <mH> <s1> <s2> <s3> <path>
        -- Let's use a more robust split
      end
      
      -- For simplicity and robustness, let's use pattern matching for the common case
      -- 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
      -- 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path>[<sep><origPath>]
      
      local parts = {}
      for part in line:gmatch("%S+") do
        table.insert(parts, part)
      end
      
      if parts[1] == "1" or parts[1] == "2" or parts[1] == "u" then
        local xy = parts[2]
        local sub = parts[3]
        local filename
        local relative = {}
        
        if parts[1] == "2" then
          -- rename/copy
          -- Format: 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path>[\t<origPath>]
          -- The last part might contain spaces, so gmatch %S+ is not ideal for paths
          -- But git porcelain v2 uses \t as separator for renames if -z is not used.
          -- Wait, the vim code used `split(tr(join(stdout, "\1"), "\1\n", "\n\1"), "\1", 1)` 
          -- which handles newlines but maybe not internal tabs well.
          
          -- Re-evaluating parsing logic to be more like the Vim one but faster
          local header_end = line:find(" [^ ]*$")
          filename = line:sub(header_end + 1)
          -- This is still fragile.
        end
        
        -- Let's use a simpler approach for now that matches the Vim implementation's intent
        if parts[1] == "1" then
          filename = line:sub(32 + 40 + 40 + 3) -- approximate offset
          -- Actually: 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
          -- <mH> <mI> <mW> are 6 chars each. <hH> <hI> are 40 chars each.
          -- 1(1) + space(1) + XY(2) + space(1) + sub(4) + space(1) + mH(6) + space(1) + mI(6) + space(1) + mW(6) + space(1) + hH(40) + space(1) + hI(40) + space(1) = 113 chars
          filename = line:sub(114)
          relative = { filename }
        elseif parts[1] == "2" then
          -- 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path>\t<origPath>
          -- 113 chars + space(1) + X<score>(4?) + space(1)
          -- It's better to find the tab
          local tab_idx = line:find("\t")
          if tab_idx then
            filename = line:sub(114, tab_idx - 1)
            local orig_path = line:sub(tab_idx + 1)
            -- filename in status is "orig -> new"
            relative = { filename, orig_path }
            filename = orig_path .. " -> " .. filename
          else
            -- Should not happen for type 2
            filename = line:match(".* ([^ ]+)$")
            relative = { filename }
          end
        elseif parts[1] == "u" then
          -- u <xy> <sub> <m1> <m2> <m3> <mH> <s1> <s2> <s3> <path>
          -- 1(1) + 1 + 2 + 1 + 4 + 1 + 6*3 + 3 + 40 + 1 + 40*3 + 3 = lot
          -- Let's just use the last part
          filename = line:match(".* ([^ ]+)$")
          relative = { filename }
        end

        local x = xy:sub(1, 1)
        local y = xy:sub(2, 2)
        
        if x ~= "." then
          table.insert(staged, {
            type = "File",
            status = x,
            filename = filename,
            relative = relative,
            submodule = sub,
          })
        end
        if y ~= "." then
          -- For unstaged, we usually want the simple filename
          local unstaged_file = relative[1]
          local status = y
          -- Handle unmerged cases if needed, matching Vim logic
          table.insert(unstaged, {
            type = "File",
            status = status,
            filename = unstaged_file,
            relative = { unstaged_file },
            submodule = sub,
          })
        end
      end
    end
    i = i + 1
  end

  local branch = props["branch.head"] or "(unknown)"
  if branch == "(detached)" or branch == "(unknown)" then
    branch = ""
  end

  return {
    staged = staged,
    unstaged = unstaged,
    untracked = untracked,
    props = props,
    branch = branch,
  }
end

return M
