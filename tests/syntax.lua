local bad = 0
for _, f in ipairs(arg) do
  local fn, err = loadfile(f)
  if not fn then print("SYNTAX ERROR: " .. err); bad = bad + 1 end
end
print(("checked %d files, %d errors"):format(#arg, bad))
