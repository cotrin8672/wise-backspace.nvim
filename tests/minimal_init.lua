local root = vim.fn.getcwd()

vim.opt.runtimepath:prepend(root)
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.compatible = false
