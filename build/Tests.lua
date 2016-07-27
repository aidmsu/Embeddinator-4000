-- Tests/examples helpers

function SetupTestProject(name, extraFiles)
  SetupTestGeneratorProject(name)
  SetupTestNativeProject(name)  
  SetupTestProjectsCSharp(name, nil, extraFiles)
end

function SetupManagedTestProject()
    kind "SharedLib"
    language "C#"  
    flags { "Unsafe" }
    SetupManagedProject()
end

function SetupTestGeneratorProject(name, depends)
  project(name .. ".Gen")
    SetupManagedTestProject()
    kind "ConsoleApp"
    
    files { name .. ".Gen.cs" }

    dependson { name .. ".Managed" }

    linktable = {
      "System.Core",
      "native-binder",
    }

    if depends ~= nil then
      table.insert(linktable, depends .. ".Gen")
    end

    links(linktable)
end

function SetupTestGeneratorBuildEvent(name)
  local runtimeExe = os.is("windows") and "" or "mono --debug "
  if string.starts(action, "vs") then
    local exePath = SafePath("$(TargetDir)" .. name .. ".Gen.exe")
    prebuildcommands { runtimeExe .. exePath }
  else
    local exePath = SafePath("%{cfg.buildtarget.directory}/" .. name .. ".Gen.exe")
    prebuildcommands { runtimeExe .. exePath }
  end
end

local function SetupMono()
  local monoDir = ''

  -- Find system-specific Mono include/library paths.
  -- For Windows, first search the default Mono install location.
  local monoDefaultWindowsDir = "C:\\Program Files (x86)\\Mono"
  if os.isdir(monoDefaultWindowsDir) then
    monoDir = monoDefaultWindowsDir
  end

  if not os.isdir(monoDir) then
    error("Could not find Mono install location, please specify it manually")
  end

  includedirs { path.join(monoDir, "include", "mono-2.0") }
  libdirs { path.join(monoDir, "lib") }
  links { "monosgen-2.0" }
end

function SetupTestNativeProject(name, depends)
  if string.starts(action, "vs") and not os.is("windows") then
    return
  end

  project(name .. ".C")
    SetupNativeProject()

    kind "SharedLib"
    language "C"

    defines { "MONO_DLL_EXPORT" }

    flags { common_flags }
    files
    {
      path.join(gendir, name, name .. ".h"),
      path.join(gendir, name, name .. ".c")
    }

    dependson { name .. ".Gen" }

    if depends ~= nil then
      links { depends .. ".C" }
    end

    SetupTestGeneratorBuildEvent(name)
    SetupMono()
end

function SetupTestProjectsCSharp(name, depends, extraFiles)
  project(name .. ".Managed")
    SetupManagedTestProject()

    files
    {
      files { name .. ".cs" }
    }
    if extraFiles ~= nil then
      for _, file in pairs(extraFiles) do
        files { file .. ".cs" }
      end
    end

    linktable = { }

    if depends ~= nil then
      table.insert(linktable, depends .. ".Managed")
    end

    links(linktable)

  project(name .. ".Tests.Managed")
    SetupNativeProject()
    language "C++"
    kind "ConsoleApp"

    includedirs
    {
      path.join(gendir, name),
      path.join(depsdir, "../catch/include")
    }

    files { name .. ".Tests.cpp" }
    links { name .. ".C" }
    dependson { name .. ".Managed" }
end