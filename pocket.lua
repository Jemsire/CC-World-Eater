local src, dest = ...

-- WORLD EATER: Handle dual-drive setup
-- src should be disk or disk2, dest is typically the pocket computer's root
fs.copy(fs.combine(src, 'pocket_files/update'), fs.combine(dest, 'update'))
file = fs.open(fs.combine(dest, 'hub_id'), 'w')
file.write(os.getComputerID())
file.close()