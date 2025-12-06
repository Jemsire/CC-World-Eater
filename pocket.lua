local src, dest = ...

-- WORLD EATER: Copy pocket files from disk
-- src should be disk, dest is typically the pocket computer's root
fs.copy(fs.combine(src, 'pocket_files/update'), fs.combine(dest, 'update'))
file = fs.open(fs.combine(dest, 'hub_id'), 'w')
file.write(os.getComputerID())
file.close()