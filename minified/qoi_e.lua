local e={}local t=_G.bit32 or _G.bit local a=string.char local
o=tonumber("11111110",2)local i=tonumber("11111111",2)local
n=tonumber("00000000",2)local s=tonumber("01000000",2)local
h=tonumber("10000000",2)local r=tonumber("11000000",2)local function
d(l,u,c,m)local f="qoif"local
w=a(t.band(0xFF,t.rshift(l,8*3)))..a(t.band(0xFF,t.rshift(l,8*2)))..a(t.band(0xFF,t.rshift(l,8*1)))..a(t.band(0xFF,l))local
y=a(t.band(0xFF,t.rshift(u,8*3)))..a(t.band(0xFF,t.rshift(u,8*2)))..a(t.band(0xFF,t.rshift(u,8*1)))..a(t.band(0xFF,u))return
f..w..y..a(c=="RGB"and 3 or 4)..a(m=="SRGB_LINEAR"and 1 or 0)end local p local
v local b local g local k local q local j local x local function z(E,T,A)local
O=0 local I=T local N,S,H,R=k,q,j,x while true do local D=p==N and v==S and
b==H and g==R if not D or O>=62 then break else O=O+1 end T=T+1 if
T>A.pixel_count then break end N,S,H,R=A.get_pixel(T)end if O>0 then
E[#E+1]=a(r+(O-1))end if O>1 then return true,I+O-1 else return O>0,I end end
local function L(U,C,M)local F=(k*3+q*5+j*7+x*11)%64 local W=4*(F+1)local
Y=M.pixel_hashmap local P=Y[W-3]==k and Y[W-2]==q and Y[W-1]==j and Y[W]==x if
P then U[#U+1]=a(n+F)end return P,C end local function V(B,G)if x~=g then
return false,G end local K=(k-p)%256 local Q=(q-v)%256 local J=(j-b)%256
K=(K+2)%256 Q=(Q+2)%256 J=(J+2)%256 local X=K>=0 and K<=3 and Q>=0 and Q<=3 and
J>=0 and J<=3 if X then local Z=(K*2^4)+(Q*2^2)+J B[#B+1]=a(s+Z)end return X,G
end local function et(tt,at)if x~=g then return false,at end local
ot=(k-p+256)%256 local it=(q-v+256)%256 local nt=(j-b+256)%256 if ot>127 then
ot=ot-256 end if it>127 then it=it-256 end if nt>127 then nt=nt-256 end local
st=ot-it local ht=nt-it local rt=it>=-32 and it<=31 and st>=-8 and st<=7 and
ht>=-8 and ht<=7 if rt then local dt=(it+32)+h local
lt=(st+8)*16+(ht+8)tt[#tt+1]=a(dt,lt)end return rt,at end local function
ut(ct,mt)if x~=g then return false,mt end ct[#ct+1]=a(o,k,q,j)return true,mt
end local function ft(wt,yt)wt[#wt+1]=a(i,k,q,j,x)return true,yt end function
e.encode(pt,vt,bt,gt,kt,qt)local jt=""local xt=vt or#pt[1]local zt=bt or#pt
p,k=0,0 v,q=0,0 b,j=0,0 g,x=255,255 local Et={}for Tt=1,64*4 do Et[Tt]=0 end
local At={}local Ot=1 local function It(Nt,St,Ht,Rt)local
Dt=(Nt*3+St*5+Ht*7+Rt*11)%64 local Lt=4*(Dt+1)Et[Lt-3]=Nt Et[Lt-2]=St
Et[Lt-1]=Ht Et[Lt]=Rt end local Ut=2^8 local Ct=gt and 1/(16^6)or 1/(16^4)local
Mt=gt and 1/(16^4)or 1/(16^2)local Ft=gt and 1/(16^2)or 1/(1)local Wt=gt and
1/(1)or 0 local Yt=xt*zt local Pt=type(pt[1][1])local Vt=math.ceil local
Bt=math.floor local function Gt(Kt)local Qt=Vt(Kt/xt)local Jt=(Kt-1)%xt+1 local
Xt=pt[Qt][Jt]local Zt,ea,ta,aa if Pt=="number"then local oa=Xt*Ct local
ia=Xt*Mt local na=Xt*Ft local sa=Xt*Wt oa=oa-oa%1 ia=ia-ia%1 na=na-na%1
sa=sa-sa%1 Zt,ea,ta,aa=oa%Ut,ia%Ut,na%Ut,gt and(sa%Ut)or 255 elseif
Pt=="table"then local ha=Xt[1]*255 local ra=Xt[2]*255 local da=Xt[3]*255 local
la=(Xt[4]or 1)*255 Zt,ea,ta,aa=ha-ha%1,ra-ra%1,da-da%1,gt and(la-la%1)or 255
end return Zt,ea,ta,aa end local ua={z,L,V,et,ut,ft,}local ca=#ua local
ma={get_pixel=Gt,pixel_hashmap=Et,pixel_count=Yt,}while Ot<=Yt do
k,q,j,x=Gt(Ot)for fa=1,ca do local wa,ya=ua[fa](At,Ot,ma)if wa then Ot=ya break
end end p,v,b,g=k,q,j,x It(k,q,j,x)if(Ot%100000==0)and os.queueEvent then
os.queueEvent("qoi_encode_yield")os.pullEvent("qoi_encode_yield")end Ot=Ot+1
end jt=jt..table.concat(At,"").."\0\0\0\0\0\0\0\1"jt=d(xt,zt,gt
and"RGBA"or"RGB",qt or"SRGB_LINEAR_ALPHA")..jt if kt then local
pa=fs.open(kt,"wb")if pa then pa.write(jt)pa.close()end end return jt end
return e