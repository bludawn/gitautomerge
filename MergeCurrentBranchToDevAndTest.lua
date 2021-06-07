-- 将当前分支合并到 dev/test分支
-- 如果是dev/test分支，则不处理
local delimeter = package.config:sub(1, 1)
local isUnix = nil
local sysName = nil

if delimeter == "/" then
    isUnix = true
    sysName = "unix"
end
if delimeter == "\\" then
    isUnix = false
    sysName = "windows"
end
if isUnix == nil then
    return
end
print("系统是：", sysName)


local A, codePage, pause
if isUnix == true then

    -- unix
    A = function(input)
        return input
    end

    codePage = function(codePage)
    end

    pause = function()
        os.execute("sleep 600")
    end

else

    -- windows
    local ffi = require 'ffi'
    ffi.cdef[[
    int MultiByteToWideChar(unsigned int CodePage,
        unsigned long dwFlags,
        const char* lpMultiByteStr,
        int cbMultiByte,
        wchar_t* lpWideCharStr,
        int cchWideChar);

    int WideCharToMultiByte(unsigned int CodePage,
        unsigned long dwFlags,
        const wchar_t* lpWideCharStr,
        int cchWideChar,
        char* lpMultiByteStr,
        int cchMultiByte,
        const char* lpDefaultChar,
        int* pfUsedDefaultChar);
    ]]

    local CP_UTF8 = 65001
    local CP_ACP = 0

    -- UTF-8 to ANSI
    A = function(input)
        local wlen = ffi.C.MultiByteToWideChar(CP_UTF8, 0, input, #input, nil, 0)
        local wstr = ffi.new('wchar_t[?]', wlen + 1)
        ffi.C.MultiByteToWideChar(CP_UTF8, 0, input, #input, wstr, wlen)

        local len = ffi.C.WideCharToMultiByte(CP_ACP, 0, wstr, wlen, nil, 0, nil, nil)
        local str = ffi.new('char[?]', len + 1)
        ffi.C.WideCharToMultiByte(CP_ACP, 0, wstr, wlen, str, len, nil, nil)

        return ffi.string(str)
    end

    codePage = function(pageCode)
        os.execute("chcp " .. pageCode)    
    end

    pause = function()
        os.execute("pause")
    end

end

codePage(65001)

local execute = function(cmd, ansi)
    local tmpFilename = "delete.me"
    local runCmd = cmd .. " >> " .. tmpFilename
    -- print(cmd)
    -- cmd = toansi(cmd)
    if ansi == nil then
        ansi = true
    end
    if ansi == true then
        runCmd = A(runCmd)
    end
    local code = os.execute(runCmd)

    local file = io.open(tmpFilename)
    local content = file:read("*a")
    io.close(file)
    os.remove(tmpFilename)

    if code ~= 0 then
        print("出现错误：" .. cmd, "code: ", tostring(code))
        pause()
        os.exit()
    end

    print(tostring(content))
    
    return content
end


local readLine = function(str, callback)
    local splits = string.split(str, '\n')
    for _, line in ipairs(splits) do
        callback(line)
    end
end

string.split = function(s, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end

    local start = 1
    local t = {}
    while true do
    local pos = string.find (s, delim, start, true) -- plain find
        if not pos then
          break
        end

        table.insert (t, string.sub (s, start, pos - 1))
        start = pos + string.len (delim)
    end
    table.insert (t, string.sub (s, start))

    return t
end


-- 检测是否将git加入到全据比那辆
local ret = execute("git --version")
if not string.find(ret, "version") then
    print("git没有加入到环境变量，请先设置")
    return
end

local ret = execute("git branch")
local currentBranch = nil
readLine(ret, function(line)
    if string.find(line, "*") == 1 then
        line = string.gsub(line, "*", "")
        line = string.gsub(line, " ", "")
        line = string.gsub(line, "\r", "")
        line = string.gsub(line, "\n", "")
        line = string.gsub(line, "\t", "")
        currentBranch = line
    end
end)

if not currentBranch then
    print("当前目录没有git管理")
    return
end

print("当前分支 : ", currentBranch)

if currentBranch == "dev" or currentBranch == "test" or currentBranch == "master" then
    print("注意，不能在 dev,test,master 分支执行本脚本")
    return
end

-- 判断是否有改动
local ret = execute('git status')
if string.find(ret, "nothing to commit") then
else
    -- 执行git add
    execute('git add -A ./')

    -- 得到提交命令
    codePage(936)
    local msg = ''
    while #msg <= 0 do
        print(A("请输入提交日志："))
        msg = io.read()
        msg = string.gsub(msg, " ", "")
        msg = string.gsub(msg, "\n", "")
        msg = string.gsub(msg, "\r", "")
        msg = string.gsub(msg, "\t", "")
    end
    codePage(65001)
    execute('git commit -m "' .. msg ..  '"', false)
end

execute('git pull origin ' .. currentBranch) 
execute('git push origin ' .. currentBranch)


-- 合并到dev
execute('git checkout dev')
execute('git pull origin dev')
execute('git merge ' .. currentBranch)
execute('git push origin dev')

if arg[1] ~= "dev" then
    -- 合并到test
    execute('git checkout test')
    execute('git pull origin test')
    execute('git merge ' .. currentBranch)
    execute('git push origin test')
end

execute('git checkout ' .. currentBranch)

if isUnix then
print("合并完成，已经切回开发分支(ctrl+c退出)")
else
print("合并完成，已经切回开发分支")
end

pause()
