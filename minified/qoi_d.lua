local e={}local t=tonumber("11111110",2)local a=tonumber("11111111",2)local
o=tonumber("00",2)local i=tonumber("01",2)local n=tonumber("10",2)local
s=tonumber("11",2)local h=_G.bit32 or bit local function r(d)local l=d.head
d.head=l+1 return d.data:byte(l,l)end local function
u(c)return{r(c),r(c),r(c),r(c)}end local function m(f)local w=0 for y=1,4 do
local p=8*(4-y)w=w+h.lshift(f[y],p)end return w end local
v={channels={[3]="RGB",[4]="RGBA"},colspace={[0]="SRGB_LINEAR_ALPHA",[1]="SRGB_LINEAR"}}local
function b(g)local k=g.data:sub(g.head,g.head+3)g.head=g.head+4 if
k~="qoif"then error("Not a QOI file.",3)end local q=u(g)local j=u(g)local
x=r(g)local
z=r(g)return{width=m(q),height=m(j),channels=v.channels[x],colorspace=v.colspace[z]}end
local E local T local A local O local function I(N,S)local H=r(S)local
R=h.extract(N,0,6)-32 local D=h.extract(H,4,4)-8 local L=h.extract(H,0,4)-8
return(E+D+R)%256,(T+R)%256,(A+L+R)%256,O end local function U(C)local
M=h.extract(C,4,2)-2 local F=h.extract(C,2,2)-2 local W=h.extract(C,0,2)-2
return(E+M)%256,(T+F)%256,(A+W)%256,O end local function Y(P,V)local
B=h.extract(P,0,6)+1 for G=1,B do V(E,T,A,O)end end local function K(Q,J)local
X=4*(h.extract(Q,0,6)+1)return J[X-3],J[X-2],J[X-1],J[X]end local function
Z(et)return r(et),r(et),r(et),O end local function tt(at)return
r(at),r(at),r(at),r(at)end function e.decode(ot,it)local nt={head=1}if ot.data
then nt.data=ot.data elseif ot.handle then
nt.data=ot.handle.readAll()ot.handle.close()elseif ot.file then local
st=fs.open(ot.file,"rb")if st then nt.data=st.readAll()st.close()end end local
ht=b(nt)local rt={}ht.pixels=rt local dt=0 local lt={}for ut=1,64*4 do lt[ut]=0
end E=0 T=0 A=0 O=255 local ct=ht.width local mt=(it~=true)and
ht.channels=="RGBA"ht.has_alpha=mt local ft=mt and 16^6 or 16^4 local wt=mt and
16^4 or 16^2 local yt=mt and 16^2 or 1 local pt=mt and 1 or 0 local
vt=math.ceil local function bt(gt,kt,qt,jt)if not gt then
error("missing pix",2)end E=gt T=kt A=qt O=jt dt=dt+1 local xt=(dt-1)%ct+1
local zt=vt(dt/ct)if not rt[zt]then rt[zt]={}end local
Et=gt*ft+kt*wt+qt*yt+jt*pt rt[zt][xt]=Et local
Tt=4*((gt*3+kt*5+qt*7+jt*11)%64+1)lt[Tt-3]=gt lt[Tt-2]=kt lt[Tt-1]=qt lt[Tt]=jt
end local At=ht.width*ht.height while dt<At do local Ot=r(nt)if not Ot then
error("Hit stream end early.",2)end local It=h.rshift(Ot,6)if Ot==t then
bt(Z(nt))elseif Ot==a then bt(tt(nt))elseif It==o then bt(K(Ot,lt))elseif It==i
then bt(U(Ot))elseif It==n then bt(I(Ot,nt))elseif It==s then Y(Ot,bt)else
error("Invalid QOI chunk.",2)end if(dt%100000==0)and os.queueEvent then
os.queueEvent("qoi_decode_yield")os.pullEvent("qoi_decode_yield")end end return
ht end return e