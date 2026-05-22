vim.opt.runtimepath:append('.')
-- Add plenary if it's not in runtimepath (CI will handle this)
local plenary_path = os.getenv('PLENARY_PATH')
if plenary_path then
  vim.opt.runtimepath:append(plenary_path)
end
