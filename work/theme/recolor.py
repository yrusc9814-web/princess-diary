import re,glob
M={}
for c in 'F4F4F6 F2F2F5 F6F6F8 F8F8FA F2F2F4 F4F2FA'.split(): M[c]='kCellBg'
for c in 'EFEFF2 F0F0F2'.split(): M[c]='const Color(0xFFFCE8EE)'
for c in 'E2E2E6 E9E9EE DADADF D5D5DA EDEDF0 E6E6EA E4E4E8 DDDDE2 EAEAEE D0D0D5'.split(): M[c]='const Color(0xFFF5D5DE)'
for c in 'BDBDC4 C4C4CA'.split(): M[c]='const Color(0xFFF2B8C6)'
M['9E9EA6']='kRose'; M['B0B0B5']='const Color(0xFFB9AEB2)'
M.update({'8E83B5':'kRose','BDB4DD':'kRoseSoft','D9CFF1':'kPinkBorder','EDE8F7':'kPinkLine','F1E9FB':'const Color(0xFFFCE1E8)','E6F0FF':'const Color(0xFFFFF0F4)',
 'FBF9FF':'const Color(0xFFFFF8FA)','E4E2EA':'kRoseLight','FBF5FA':'const Color(0xFFFFF6F8)','F6F1FB':'const Color(0xFFFDEEF2)','3D7BFD':'kRose'})
files=[f for f in glob.glob('lib/pages/*.dart')+glob.glob('lib/widgets/*.dart') if not f.endswith('common.dart')]
for f in files:
    s=open(f).read(); o=s
    def rep(m):
        hexv=m.group(2).upper()
        return M.get(hexv, m.group(0))
    s=re.sub(r'(const )?Color\(0xFF([0-9A-Fa-f]{6})\)',rep,s)
    s=s.replace('Color(0x993D7BFD)','Color(0x99EC4A6E)')
    if s!=o: open(f,'w').write(s); print('changed',f)
