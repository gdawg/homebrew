require 'formula'

class Lua < Formula
  # 5.2 is not fully backwards compatible, and breaks e.g. luarocks.
  # It is available in Homebrew-versions for the time being.
  homepage 'http://www.lua.org/'
  url 'http://www.lua.org/ftp/lua-5.2.3.tar.gz'
  sha1 '926b7907bc8d274e063d42804666b40a3f3c124c'

  fails_with :llvm do
    build 2326
    cause "Lua itself compiles with LLVM, but may fail when other software tries to link."
  end

  option :universal
  option 'with-completion', 'Enables advanced readline support'
  option 'without-sigaction', 'Revert to ANSI signal instead of improved POSIX sigaction'

  # Be sure to build a dylib, or else runtime modules will pull in another static copy of liblua = crashy
  # See: https://github.com/Homebrew/homebrew/pull/5043
  patch :DATA

  # sigaction provided by posix signalling power patch from
  # http://lua-users.org/wiki/LuaPowerPatches
  patch do
    url "http://lua-users.org/files/wiki_insecure/power_patches/5.2/lua-5.2.3-sig_catch.patch"
    sha1 "b9a0044eb3c422f8405798c900ce31587156c7dd"
  end if build.with? "sigaction"

  # completion provided by advanced readline power patch from
  # http://lua-users.org/wiki/LuaPowerPatches
  patch do
    url "http://luajit.org/patches/lua-5.2.0-advanced_readline.patch"
    sha1 "ca405dbd126bc018980a26c2c766dfb0f82e919e"
  end if build.with? "completion"

  def install
    ENV.universal_binary if build.universal?

    # Use our CC/CFLAGS to compile.
    inreplace 'src/Makefile' do |s|
      s.remove_make_var! 'CC'
      s.change_make_var! 'CFLAGS', "#{ENV.cflags} $(MYCFLAGS)"
      s.change_make_var! 'MYLDFLAGS', ENV.ldflags
      s.sub! 'MYCFLAGS_VAL', "-fno-common -DLUA_USE_LINUX"
    end

    # Fix path in the config header
    inreplace 'src/luaconf.h', '/usr/local', HOMEBREW_PREFIX

    # Fix paths in the .pc
    # inreplace 'etc/lua.pc' do |s|
    #   s.gsub! "prefix= /usr/local", "prefix=#{HOMEBREW_PREFIX}"
    #   s.gsub! "INSTALL_MAN= ${prefix}/man/man1", "INSTALL_MAN= ${prefix}/share/man/man1"
    # end

    # this ensures that this symlinking for lua starts at lib/lua/5.x and not
    # below that, thus making luarocks work
    (HOMEBREW_PREFIX/"lib/lua"/version.to_s.split('.')[0..1].join('.')).mkpath

    system "make", "macosx", "INSTALL_TOP=#{prefix}", "INSTALL_MAN=#{man1}"
    system "make", "install", "INSTALL_TOP=#{prefix}", "INSTALL_MAN=#{man1}"

    #(lib+"pkgconfig").install 'etc/lua.pc'
  end

  test do
    output = `#{bin}/lua -e "for i=0,9 do io.write(i) end"`
    assert_equal "0123456789", output
    assert_equal 0, $?.exitstatus
  end
end

__END__
diff --git a/Makefile b/Makefile
index d2c7db4..139cdab 100644
--- a/Makefile
+++ b/Makefile
@@ -20,9 +20,9 @@ INSTALL_CMOD= $(INSTALL_TOP)/lib/lua/$V
 
 # How to install. If your install program does not support "-p", then
 # you may have to run ranlib on the installed liblua.a.
-INSTALL= install -p
-INSTALL_EXEC= $(INSTALL) -m 0755
-INSTALL_DATA= $(INSTALL) -m 0644
+INSTALL= libtool -dynamic -o $(INSTALL_LIB)/$(TO_LIB) $(TO_LIB)
+INSTALL_EXEC= cp
+INSTALL_DATA= cp
 #
 # If you don't have "install" you can use "cp" instead.
 # INSTALL= cp -p
@@ -41,7 +42,7 @@ PLATS= aix ansi bsd freebsd generic linux macosx mingw posix solaris
 # What to install.
 TO_BIN= lua luac
 TO_INC= lua.h luaconf.h lualib.h lauxlib.h lua.hpp
-TO_LIB= liblua.a
+TO_LIB= liblua.5.2.3.dylib
 TO_MAN= lua.1 luac.1
 
 # Lua version and release.
@@ -63,6 +64,8 @@ install: dummy
 	cd src && $(INSTALL_DATA) $(TO_INC) $(INSTALL_INC)
 	cd src && $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIB)
 	cd doc && $(INSTALL_DATA) $(TO_MAN) $(INSTALL_MAN)
+	ln -s -f liblua.5.2.3.dylib $(INSTALL_LIB)/liblua.5.2.dylib
+	ln -s -f liblua.5.2.dylib $(INSTALL_LIB)/liblua.dylib
 
 uninstall:
 	cd src && cd $(INSTALL_BIN) && $(RM) $(TO_BIN)
diff --git a/src/Makefile b/src/Makefile
index 7b4b2b7..e069644 100644
--- a/src/Makefile
+++ b/src/Makefile
@@ -28,7 +28,7 @@ MYOBJS=
 
 PLATS= aix ansi bsd freebsd generic linux macosx mingw posix solaris
 
-LUA_A=	liblua.a
+LUA_A=	liblua.5.2.3.dylib
 CORE_O=	lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o \
 	lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o \
 	ltm.o lundump.o lvm.o lzio.o
@@ -56,11 +56,13 @@ o:	$(ALL_O)
 a:	$(ALL_A)
 
 $(LUA_A): $(BASE_O)
-	$(AR) $@ $(BASE_O)
-	$(RANLIB) $@
+	$(CC) -dynamiclib -install_name HOMEBREW_PREFIX/lib/liblua.5.2.dylib \
+		-compatibility_version 5.2 -current_version 5.2.3 \
+		-o liblua.5.2.3.dylib $^
 
 $(LUA_T): $(LUA_O) $(LUA_A)
-	$(CC) -o $@ $(LDFLAGS) $(LUA_O) $(LUA_A) $(LIBS)
+	$(CC) -fno-common $(MYLDFLAGS) \
+		-o $@ $(LUA_O) $(LUA_A) -L. -llua.5.2.3 $(LIBS)
 
 $(LUAC_T): $(LUAC_O) $(LUA_A)
 	$(CC) -o $@ $(LDFLAGS) $(LUAC_O) $(LUA_A) $(LIBS)
@@ -106,7 +108,7 @@ linux:
 	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_LINUX" SYSLIBS="-Wl,-E -ldl -lreadline"
 
 macosx:
-	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX" SYSLIBS="-lreadline" CC=cc
+	$(MAKE) $(ALL) MYCFLAGS="MYCFLAGS_VAL" MYLIBS="-lreadline"
 
 mingw:
 	$(MAKE) "LUA_A=lua52.dll" "LUA_T=lua.exe" \
