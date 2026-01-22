from pathlib import Path
p=Path('lib/screens/create_routine/widgets/dia_expansion_tile.dart').read_text()
par=0; sq=0; cu=0
for i,ch in enumerate(p, start=1):
    if ch=='(':
        par+=1
    elif ch==')':
        par-=1
    elif ch=='[':
        sq+=1
    elif ch==']':
        sq-=1
    elif ch=='{':
        cu+=1
    elif ch=='}':
        cu-=1
    if par<0 or sq<0 or cu<0:
        lines=p[:i].splitlines()
        line=len(lines)
        col=len(lines[-1])
        print('Negative at',line,col,'char',ch)
        break
else:
    print('balances non-negative; final counts par,sq,cu=',par,sq,cu)
