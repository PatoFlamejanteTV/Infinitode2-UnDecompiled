REM Generates Lua definition files in scripts/.definitions/classes
REM Requires Java to be installed - Java 8 is perfect but later versions should work too. If script does not do anything, make sure java is installed (run "java -version")
REM Relies on files in res/luaj folder and uses them as a configuration

REM Log file: luadef-gen-log.txt. Search for "/!\" lines to see if something gone wrong
REM As long as you receive "all done" at the end, there's noting to worry about - actual definitions were properly generated, worst that could happen is some missing documentation for a things you probably won't use anyways
REM If you receive messages about things that are missing, it may mean that this program is pointed to the Javadocs that do not fit the actual versions of the libraries used in the game. You can change links to Javadocs to fix these warnings
REM Note: by default, everything uses javadoc for Java 8, because that's what is available on all platforms. If you are running a newer version of Java, a documentation for a couple of things will be missing - if it bothers you, run this script with Java 8
REM Also, you don't need this .bat file - just run the command directly. Running it through infinitode-2.exe will not work as it can't find many classes.

REM You can add -v at the end of this line to print a verbose output
java -jar infinitode-2.jar generate-lua-defs