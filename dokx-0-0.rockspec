package = 'dokx'
version = '0-0'

source = {
   url = 'git://github.com/d11/torch-dokx.git',
   branch = 'master'
}

description = {
  summary = "Torch documentation scripts",
  homepage = "http://d11.github.io/torch-dokx",
  detailed = "dokx creates nice documentation for your Torch packages",
  license = "BSD",
  maintainer = "Dan Horgan <danhgn+github@gmail.com>"
}

dependencies = { 'torch >= 7.0', 'sundown', 'logroll', 'lpeg', 'json', 'luasocket', 'dok', 'trepl', 'util' }
build = {
   type = "command",
   build_command = [[
cmake -E make_directory build;
cd build;
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$(LUA_BINDIR)/.." -DCMAKE_INSTALL_PREFIX="$(PREFIX)"; 
$(MAKE)
   ]],
   install_command = "cd build && $(MAKE) install"
}
