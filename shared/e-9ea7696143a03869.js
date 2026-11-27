(()=>{var Ju=0,Qc=1,Ku=2;var jc=1,Ka=2,oi=3,Si=0,je=1,Ce=2,Ri=0,ws=1,Eo=2,th=3,eh=4,Qu=5,Ki=100,ju=101,td=102,ed=103,nd=104,id=200,sd=201,rd=202,od=203,Sa=204,wa=205,ad=206,ld=207,cd=208,hd=209,ud=210,dd=211,fd=212,pd=213,md=214,Qa=0,ja=1,tl=2,Ts=3,el=4,nl=5,il=6,sl=7,rl=0,gd=1,xd=2,Ci=0,yd=1,_d=2,vd=3,ol=4,Md=5,Ed=6,Sd=7;var nh=300,Ls=301,Ds=302,al=303,ll=304,So=306,Ge=1e3,Ji=1001,hr=1002,xn=1003,wd=1004;var wo=1005;var Xn=1006,cl=1007;var is=1008;var ai=1009,ih=1010,sh=1011,_r=1012,hl=1013,ss=1014,Yn=1015,vr=1016,ul=1017,dl=1018,Us=1020,rh=35902,oh=1021,ah=1022,Un=1023,lh=1024,ch=1025,Ss=1026,bs=1027,fl=1028,pl=1029,hh=1030,ml=1031;var gl=1033,To=33776,bo=33777,Ao=33778,Ro=33779,xl=35840,yl=35841,_l=35842,vl=35843,Ml=36196,El=37492,Sl=37496,wl=37808,Tl=37809,bl=37810,Al=37811,Rl=37812,Cl=37813,Pl=37814,Il=37815,Ll=37816,Dl=37817,Ul=37818,Nl=37819,Fl=37820,Ol=37821,Co=36492,Hl=36494,Bl=36495,uh=36283,kl=36284,zl=36285,Gl=36286;var qr=2300,Ta=2301,Ea=2302,zc=2400,Gc=2401,Vc=2402;var Td=3200,bd=3201;var Vl=0,Ad=1,Pi="",Pe="srgb",As="srgb-linear",Yr="linear",Me="srgb";var Es=7680;var Wc=519,Rd=512,Cd=513,Pd=514,dh=515,Id=516,Ld=517,Dd=518,Ud=519,Xc=35044;var fh="300 es",ei=2e3,$r=2001,wi=class{addEventListener(t,e){this._listeners===void 0&&(this._listeners={});let i=this._listeners;i[t]===void 0&&(i[t]=[]),i[t].indexOf(e)===-1&&i[t].push(e)}hasEventListener(t,e){if(this._listeners===void 0)return!1;let i=this._listeners;return i[t]!==void 0&&i[t].indexOf(e)!==-1}removeEventListener(t,e){if(this._listeners===void 0)return;let s=this._listeners[t];if(s!==void 0){let r=s.indexOf(e);r!==-1&&s.splice(r,1)}}dispatchEvent(t){if(this._listeners===void 0)return;let i=this._listeners[t.type];if(i!==void 0){t.target=this;let s=i.slice(0);for(let r=0,a=s.length;r<a;r++)s[r].call(this,t);t.target=null}}},sn=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"];var mc=Math.PI/180,ba=180/Math.PI;function Mr(){let n=Math.random()*4294967295|0,t=Math.random()*4294967295|0,e=Math.random()*4294967295|0,i=Math.random()*4294967295|0;return(sn[n&255]+sn[n>>8&255]+sn[n>>16&255]+sn[n>>24&255]+"-"+sn[t&255]+sn[t>>8&255]+"-"+sn[t>>16&15|64]+sn[t>>24&255]+"-"+sn[e&63|128]+sn[e>>8&255]+"-"+sn[e>>16&255]+sn[e>>24&255]+sn[i&255]+sn[i>>8&255]+sn[i>>16&255]+sn[i>>24&255]).toLowerCase()}function ie(n,t,e){return Math.max(t,Math.min(e,n))}function Sp(n,t){return(n%t+t)%t}function gc(n,t,e){return(1-e)*n+e*t}function Or(n,t){switch(t.constructor){case Float32Array:return n;case Uint32Array:return n/4294967295;case Uint16Array:return n/65535;case Uint8Array:return n/255;case Int32Array:return Math.max(n/2147483647,-1);case Int16Array:return Math.max(n/32767,-1);case Int8Array:return Math.max(n/127,-1);default:throw new Error("Invalid component type.")}}function mn(n,t){switch(t.constructor){case Float32Array:return n;case Uint32Array:return Math.round(n*4294967295);case Uint16Array:return Math.round(n*65535);case Uint8Array:return Math.round(n*255);case Int32Array:return Math.round(n*2147483647);case Int16Array:return Math.round(n*32767);case Int8Array:return Math.round(n*127);default:throw new Error("Invalid component type.")}}var at=class n{constructor(t=0,e=0){n.prototype.isVector2=!0,this.x=t,this.y=e}get width(){return this.x}set width(t){this.x=t}get height(){return this.y}set height(t){this.y=t}set(t,e){return this.x=t,this.y=e,this}setScalar(t){return this.x=t,this.y=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;default:throw new Error("index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;default:throw new Error("index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y)}copy(t){return this.x=t.x,this.y=t.y,this}add(t){return this.x+=t.x,this.y+=t.y,this}addScalar(t){return this.x+=t,this.y+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this}subScalar(t){return this.x-=t,this.y-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this}multiply(t){return this.x*=t.x,this.y*=t.y,this}multiplyScalar(t){return this.x*=t,this.y*=t,this}divide(t){return this.x/=t.x,this.y/=t.y,this}divideScalar(t){return this.multiplyScalar(1/t)}applyMatrix3(t){let e=this.x,i=this.y,s=t.elements;return this.x=s[0]*e+s[3]*i+s[6],this.y=s[1]*e+s[4]*i+s[7],this}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this}clamp(t,e){return this.x=ie(this.x,t.x,e.x),this.y=ie(this.y,t.y,e.y),this}clampScalar(t,e){return this.x=ie(this.x,t,e),this.y=ie(this.y,t,e),this}clampLength(t,e){let i=this.length();return this.divideScalar(i||1).multiplyScalar(ie(i,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(t){return this.x*t.x+this.y*t.y}cross(t){return this.x*t.y-this.y*t.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(t){let e=Math.sqrt(this.lengthSq()*t.lengthSq());if(e===0)return Math.PI/2;let i=this.dot(t)/e;return Math.acos(ie(i,-1,1))}distanceTo(t){return Math.sqrt(this.distanceToSquared(t))}distanceToSquared(t){let e=this.x-t.x,i=this.y-t.y;return e*e+i*i}manhattanDistanceTo(t){return Math.abs(this.x-t.x)+Math.abs(this.y-t.y)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this}lerpVectors(t,e,i){return this.x=t.x+(e.x-t.x)*i,this.y=t.y+(e.y-t.y)*i,this}equals(t){return t.x===this.x&&t.y===this.y}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this}rotateAround(t,e){let i=Math.cos(e),s=Math.sin(e),r=this.x-t.x,a=this.y-t.y;return this.x=r*i-a*s+t.x,this.y=r*s+a*i+t.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}},Qt=class n{constructor(t,e,i,s,r,a,o,l,c){n.prototype.isMatrix3=!0,this.elements=[1,0,0,0,1,0,0,0,1],t!==void 0&&this.set(t,e,i,s,r,a,o,l,c)}set(t,e,i,s,r,a,o,l,c){let h=this.elements;return h[0]=t,h[1]=s,h[2]=o,h[3]=e,h[4]=r,h[5]=l,h[6]=i,h[7]=a,h[8]=c,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(t){let e=this.elements,i=t.elements;return e[0]=i[0],e[1]=i[1],e[2]=i[2],e[3]=i[3],e[4]=i[4],e[5]=i[5],e[6]=i[6],e[7]=i[7],e[8]=i[8],this}extractBasis(t,e,i){return t.setFromMatrix3Column(this,0),e.setFromMatrix3Column(this,1),i.setFromMatrix3Column(this,2),this}setFromMatrix4(t){let e=t.elements;return this.set(e[0],e[4],e[8],e[1],e[5],e[9],e[2],e[6],e[10]),this}multiply(t){return this.multiplyMatrices(this,t)}premultiply(t){return this.multiplyMatrices(t,this)}multiplyMatrices(t,e){let i=t.elements,s=e.elements,r=this.elements,a=i[0],o=i[3],l=i[6],c=i[1],h=i[4],d=i[7],u=i[2],f=i[5],x=i[8],M=s[0],m=s[3],p=s[6],S=s[1],E=s[4],g=s[7],C=s[2],A=s[5],_=s[8];return r[0]=a*M+o*S+l*C,r[3]=a*m+o*E+l*A,r[6]=a*p+o*g+l*_,r[1]=c*M+h*S+d*C,r[4]=c*m+h*E+d*A,r[7]=c*p+h*g+d*_,r[2]=u*M+f*S+x*C,r[5]=u*m+f*E+x*A,r[8]=u*p+f*g+x*_,this}multiplyScalar(t){let e=this.elements;return e[0]*=t,e[3]*=t,e[6]*=t,e[1]*=t,e[4]*=t,e[7]*=t,e[2]*=t,e[5]*=t,e[8]*=t,this}determinant(){let t=this.elements,e=t[0],i=t[1],s=t[2],r=t[3],a=t[4],o=t[5],l=t[6],c=t[7],h=t[8];return e*a*h-e*o*c-i*r*h+i*o*l+s*r*c-s*a*l}invert(){let t=this.elements,e=t[0],i=t[1],s=t[2],r=t[3],a=t[4],o=t[5],l=t[6],c=t[7],h=t[8],d=h*a-o*c,u=o*l-h*r,f=c*r-a*l,x=e*d+i*u+s*f;if(x===0)return this.set(0,0,0,0,0,0,0,0,0);let M=1/x;return t[0]=d*M,t[1]=(s*c-h*i)*M,t[2]=(o*i-s*a)*M,t[3]=u*M,t[4]=(h*e-s*l)*M,t[5]=(s*r-o*e)*M,t[6]=f*M,t[7]=(i*l-c*e)*M,t[8]=(a*e-i*r)*M,this}transpose(){let t,e=this.elements;return t=e[1],e[1]=e[3],e[3]=t,t=e[2],e[2]=e[6],e[6]=t,t=e[5],e[5]=e[7],e[7]=t,this}getNormalMatrix(t){return this.setFromMatrix4(t).invert().transpose()}transposeIntoArray(t){let e=this.elements;return t[0]=e[0],t[1]=e[3],t[2]=e[6],t[3]=e[1],t[4]=e[4],t[5]=e[7],t[6]=e[2],t[7]=e[5],t[8]=e[8],this}setUvTransform(t,e,i,s,r,a,o){let l=Math.cos(r),c=Math.sin(r);return this.set(i*l,i*c,-i*(l*a+c*o)+a+t,-s*c,s*l,-s*(-c*a+l*o)+o+e,0,0,1),this}scale(t,e){return this.premultiply(xc.makeScale(t,e)),this}rotate(t){return this.premultiply(xc.makeRotation(-t)),this}translate(t,e){return this.premultiply(xc.makeTranslation(t,e)),this}makeTranslation(t,e){return t.isVector2?this.set(1,0,t.x,0,1,t.y,0,0,1):this.set(1,0,t,0,1,e,0,0,1),this}makeRotation(t){let e=Math.cos(t),i=Math.sin(t);return this.set(e,-i,0,i,e,0,0,0,1),this}makeScale(t,e){return this.set(t,0,0,0,e,0,0,0,1),this}equals(t){let e=this.elements,i=t.elements;for(let s=0;s<9;s++)if(e[s]!==i[s])return!1;return!0}fromArray(t,e=0){for(let i=0;i<9;i++)this.elements[i]=t[i+e];return this}toArray(t=[],e=0){let i=this.elements;return t[e]=i[0],t[e+1]=i[1],t[e+2]=i[2],t[e+3]=i[3],t[e+4]=i[4],t[e+5]=i[5],t[e+6]=i[6],t[e+7]=i[7],t[e+8]=i[8],t}clone(){return new this.constructor().fromArray(this.elements)}},xc=new Qt;function ph(n){for(let t=n.length-1;t>=0;--t)if(n[t]>=65535)return!0;return!1}function ur(n){return document.createElementNS("http://www.w3.org/1999/xhtml",n)}function Nd(){let n=ur("canvas");return n.style.display="block",n}var Tu={};function Ns(n){n in Tu||(Tu[n]=!0,console.warn(n))}function Fd(n,t,e){return new Promise(function(i,s){function r(){switch(n.clientWaitSync(t,n.SYNC_FLUSH_COMMANDS_BIT,0)){case n.WAIT_FAILED:s();break;case n.TIMEOUT_EXPIRED:setTimeout(r,e);break;default:i()}}setTimeout(r,e)})}function Od(n){let t=n.elements;t[2]=.5*t[2]+.5*t[3],t[6]=.5*t[6]+.5*t[7],t[10]=.5*t[10]+.5*t[11],t[14]=.5*t[14]+.5*t[15]}function Hd(n){let t=n.elements;t[11]===-1?(t[10]=-t[10]-1,t[14]=-t[14]):(t[10]=-t[10],t[14]=-t[14]+1)}var bu=new Qt().set(.4123908,.3575843,.1804808,.212639,.7151687,.0721923,.0193308,.1191948,.9505322),Au=new Qt().set(3.2409699,-1.5373832,-.4986108,-.9692436,1.8759675,.0415551,.0556301,-.203977,1.0569715);function wp(){let n={enabled:!0,workingColorSpace:As,spaces:{},convert:function(s,r,a){return this.enabled===!1||r===a||!r||!a||(this.spaces[r].transfer===Me&&(s.r=Mi(s.r),s.g=Mi(s.g),s.b=Mi(s.b)),this.spaces[r].primaries!==this.spaces[a].primaries&&(s.applyMatrix3(this.spaces[r].toXYZ),s.applyMatrix3(this.spaces[a].fromXYZ)),this.spaces[a].transfer===Me&&(s.r=cr(s.r),s.g=cr(s.g),s.b=cr(s.b))),s},fromWorkingColorSpace:function(s,r){return this.convert(s,this.workingColorSpace,r)},toWorkingColorSpace:function(s,r){return this.convert(s,r,this.workingColorSpace)},getPrimaries:function(s){return this.spaces[s].primaries},getTransfer:function(s){return s===Pi?Yr:this.spaces[s].transfer},getLuminanceCoefficients:function(s,r=this.workingColorSpace){return s.fromArray(this.spaces[r].luminanceCoefficients)},define:function(s){Object.assign(this.spaces,s)},_getMatrix:function(s,r,a){return s.copy(this.spaces[r].toXYZ).multiply(this.spaces[a].fromXYZ)},_getDrawingBufferColorSpace:function(s){return this.spaces[s].outputColorSpaceConfig.drawingBufferColorSpace},_getUnpackColorSpace:function(s=this.workingColorSpace){return this.spaces[s].workingColorSpaceConfig.unpackColorSpace}},t=[.64,.33,.3,.6,.15,.06],e=[.2126,.7152,.0722],i=[.3127,.329];return n.define({[As]:{primaries:t,whitePoint:i,transfer:Yr,toXYZ:bu,fromXYZ:Au,luminanceCoefficients:e,workingColorSpaceConfig:{unpackColorSpace:Pe},outputColorSpaceConfig:{drawingBufferColorSpace:Pe}},[Pe]:{primaries:t,whitePoint:i,transfer:Me,toXYZ:bu,fromXYZ:Au,luminanceCoefficients:e,outputColorSpaceConfig:{drawingBufferColorSpace:Pe}}}),n}var pe=wp();function Mi(n){return n<.04045?n*.0773993808:Math.pow(n*.9478672986+.0521327014,2.4)}function cr(n){return n<.0031308?n*12.92:1.055*Math.pow(n,.41666)-.055}var Zs,Aa=class{static getDataURL(t){if(/^data:/i.test(t.src)||typeof HTMLCanvasElement=="undefined")return t.src;let e;if(t instanceof HTMLCanvasElement)e=t;else{Zs===void 0&&(Zs=ur("canvas")),Zs.width=t.width,Zs.height=t.height;let i=Zs.getContext("2d");t instanceof ImageData?i.putImageData(t,0,0):i.drawImage(t,0,0,t.width,t.height),e=Zs}return e.width>2048||e.height>2048?(console.warn("THREE.ImageUtils.getDataURL: Image converted to jpg for performance reasons",t),e.toDataURL("image/jpeg",.6)):e.toDataURL("image/png")}static sRGBToLinear(t){if(typeof HTMLImageElement!="undefined"&&t instanceof HTMLImageElement||typeof HTMLCanvasElement!="undefined"&&t instanceof HTMLCanvasElement||typeof ImageBitmap!="undefined"&&t instanceof ImageBitmap){let e=ur("canvas");e.width=t.width,e.height=t.height;let i=e.getContext("2d");i.drawImage(t,0,0,t.width,t.height);let s=i.getImageData(0,0,t.width,t.height),r=s.data;for(let a=0;a<r.length;a++)r[a]=Mi(r[a]/255)*255;return i.putImageData(s,0,0),e}else if(t.data){let e=t.data.slice(0);for(let i=0;i<e.length;i++)e instanceof Uint8Array||e instanceof Uint8ClampedArray?e[i]=Math.floor(Mi(e[i]/255)*255):e[i]=Mi(e[i]);return{data:e,width:t.width,height:t.height}}else return console.warn("THREE.ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),t}},Tp=0,Zr=class{constructor(t=null){this.isSource=!0,Object.defineProperty(this,"id",{value:Tp++}),this.uuid=Mr(),this.data=t,this.dataReady=!0,this.version=0}set needsUpdate(t){t===!0&&this.version++}toJSON(t){let e=t===void 0||typeof t=="string";if(!e&&t.images[this.uuid]!==void 0)return t.images[this.uuid];let i={uuid:this.uuid,url:""},s=this.data;if(s!==null){let r;if(Array.isArray(s)){r=[];for(let a=0,o=s.length;a<o;a++)s[a].isDataTexture?r.push(yc(s[a].image)):r.push(yc(s[a]))}else r=yc(s);i.url=r}return e||(t.images[this.uuid]=i),i}};function yc(n){return typeof HTMLImageElement!="undefined"&&n instanceof HTMLImageElement||typeof HTMLCanvasElement!="undefined"&&n instanceof HTMLCanvasElement||typeof ImageBitmap!="undefined"&&n instanceof ImageBitmap?Aa.getDataURL(n):n.data?{data:Array.from(n.data),width:n.width,height:n.height,type:n.data.constructor.name}:(console.warn("THREE.Texture: Unable to serialize Texture."),{})}var bp=0,an=class n extends wi{constructor(t=n.DEFAULT_IMAGE,e=n.DEFAULT_MAPPING,i=Ji,s=Ji,r=Xn,a=is,o=Un,l=ai,c=n.DEFAULT_ANISOTROPY,h=Pi){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:bp++}),this.uuid=Mr(),this.name="",this.source=new Zr(t),this.mipmaps=[],this.mapping=e,this.channel=0,this.wrapS=i,this.wrapT=s,this.magFilter=r,this.minFilter=a,this.anisotropy=c,this.format=o,this.internalFormat=null,this.type=l,this.offset=new at(0,0),this.repeat=new at(1,1),this.center=new at(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new Qt,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=h,this.userData={},this.version=0,this.onUpdate=null,this.isRenderTargetTexture=!1,this.pmremVersion=0}get image(){return this.source.data}set image(t=null){this.source.data=t}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}clone(){return new this.constructor().copy(this)}copy(t){return this.name=t.name,this.source=t.source,this.mipmaps=t.mipmaps.slice(0),this.mapping=t.mapping,this.channel=t.channel,this.wrapS=t.wrapS,this.wrapT=t.wrapT,this.magFilter=t.magFilter,this.minFilter=t.minFilter,this.anisotropy=t.anisotropy,this.format=t.format,this.internalFormat=t.internalFormat,this.type=t.type,this.offset.copy(t.offset),this.repeat.copy(t.repeat),this.center.copy(t.center),this.rotation=t.rotation,this.matrixAutoUpdate=t.matrixAutoUpdate,this.matrix.copy(t.matrix),this.generateMipmaps=t.generateMipmaps,this.premultiplyAlpha=t.premultiplyAlpha,this.flipY=t.flipY,this.unpackAlignment=t.unpackAlignment,this.colorSpace=t.colorSpace,this.userData=JSON.parse(JSON.stringify(t.userData)),this.needsUpdate=!0,this}toJSON(t){let e=t===void 0||typeof t=="string";if(!e&&t.textures[this.uuid]!==void 0)return t.textures[this.uuid];let i={metadata:{version:4.6,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(t).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(i.userData=this.userData),e||(t.textures[this.uuid]=i),i}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(t){if(this.mapping!==nh)return t;if(t.applyMatrix3(this.matrix),t.x<0||t.x>1)switch(this.wrapS){case Ge:t.x=t.x-Math.floor(t.x);break;case Ji:t.x=t.x<0?0:1;break;case hr:Math.abs(Math.floor(t.x)%2)===1?t.x=Math.ceil(t.x)-t.x:t.x=t.x-Math.floor(t.x);break}if(t.y<0||t.y>1)switch(this.wrapT){case Ge:t.y=t.y-Math.floor(t.y);break;case Ji:t.y=t.y<0?0:1;break;case hr:Math.abs(Math.floor(t.y)%2)===1?t.y=Math.ceil(t.y)-t.y:t.y=t.y-Math.floor(t.y);break}return this.flipY&&(t.y=1-t.y),t}set needsUpdate(t){t===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(t){t===!0&&this.pmremVersion++}};an.DEFAULT_IMAGE=null;an.DEFAULT_MAPPING=nh;an.DEFAULT_ANISOTROPY=1;var Le=class n{constructor(t=0,e=0,i=0,s=1){n.prototype.isVector4=!0,this.x=t,this.y=e,this.z=i,this.w=s}get width(){return this.z}set width(t){this.z=t}get height(){return this.w}set height(t){this.w=t}set(t,e,i,s){return this.x=t,this.y=e,this.z=i,this.w=s,this}setScalar(t){return this.x=t,this.y=t,this.z=t,this.w=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setZ(t){return this.z=t,this}setW(t){return this.w=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;case 2:this.z=e;break;case 3:this.w=e;break;default:throw new Error("index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(t){return this.x=t.x,this.y=t.y,this.z=t.z,this.w=t.w!==void 0?t.w:1,this}add(t){return this.x+=t.x,this.y+=t.y,this.z+=t.z,this.w+=t.w,this}addScalar(t){return this.x+=t,this.y+=t,this.z+=t,this.w+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this.z=t.z+e.z,this.w=t.w+e.w,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this.z+=t.z*e,this.w+=t.w*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this.z-=t.z,this.w-=t.w,this}subScalar(t){return this.x-=t,this.y-=t,this.z-=t,this.w-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this.z=t.z-e.z,this.w=t.w-e.w,this}multiply(t){return this.x*=t.x,this.y*=t.y,this.z*=t.z,this.w*=t.w,this}multiplyScalar(t){return this.x*=t,this.y*=t,this.z*=t,this.w*=t,this}applyMatrix4(t){let e=this.x,i=this.y,s=this.z,r=this.w,a=t.elements;return this.x=a[0]*e+a[4]*i+a[8]*s+a[12]*r,this.y=a[1]*e+a[5]*i+a[9]*s+a[13]*r,this.z=a[2]*e+a[6]*i+a[10]*s+a[14]*r,this.w=a[3]*e+a[7]*i+a[11]*s+a[15]*r,this}divide(t){return this.x/=t.x,this.y/=t.y,this.z/=t.z,this.w/=t.w,this}divideScalar(t){return this.multiplyScalar(1/t)}setAxisAngleFromQuaternion(t){this.w=2*Math.acos(t.w);let e=Math.sqrt(1-t.w*t.w);return e<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=t.x/e,this.y=t.y/e,this.z=t.z/e),this}setAxisAngleFromRotationMatrix(t){let e,i,s,r,l=t.elements,c=l[0],h=l[4],d=l[8],u=l[1],f=l[5],x=l[9],M=l[2],m=l[6],p=l[10];if(Math.abs(h-u)<.01&&Math.abs(d-M)<.01&&Math.abs(x-m)<.01){if(Math.abs(h+u)<.1&&Math.abs(d+M)<.1&&Math.abs(x+m)<.1&&Math.abs(c+f+p-3)<.1)return this.set(1,0,0,0),this;e=Math.PI;let E=(c+1)/2,g=(f+1)/2,C=(p+1)/2,A=(h+u)/4,_=(d+M)/4,T=(x+m)/4;return E>g&&E>C?E<.01?(i=0,s=.707106781,r=.707106781):(i=Math.sqrt(E),s=A/i,r=_/i):g>C?g<.01?(i=.707106781,s=0,r=.707106781):(s=Math.sqrt(g),i=A/s,r=T/s):C<.01?(i=.707106781,s=.707106781,r=0):(r=Math.sqrt(C),i=_/r,s=T/r),this.set(i,s,r,e),this}let S=Math.sqrt((m-x)*(m-x)+(d-M)*(d-M)+(u-h)*(u-h));return Math.abs(S)<.001&&(S=1),this.x=(m-x)/S,this.y=(d-M)/S,this.z=(u-h)/S,this.w=Math.acos((c+f+p-1)/2),this}setFromMatrixPosition(t){let e=t.elements;return this.x=e[12],this.y=e[13],this.z=e[14],this.w=e[15],this}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this.z=Math.min(this.z,t.z),this.w=Math.min(this.w,t.w),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this.z=Math.max(this.z,t.z),this.w=Math.max(this.w,t.w),this}clamp(t,e){return this.x=ie(this.x,t.x,e.x),this.y=ie(this.y,t.y,e.y),this.z=ie(this.z,t.z,e.z),this.w=ie(this.w,t.w,e.w),this}clampScalar(t,e){return this.x=ie(this.x,t,e),this.y=ie(this.y,t,e),this.z=ie(this.z,t,e),this.w=ie(this.w,t,e),this}clampLength(t,e){let i=this.length();return this.divideScalar(i||1).multiplyScalar(ie(i,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(t){return this.x*t.x+this.y*t.y+this.z*t.z+this.w*t.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this.z+=(t.z-this.z)*e,this.w+=(t.w-this.w)*e,this}lerpVectors(t,e,i){return this.x=t.x+(e.x-t.x)*i,this.y=t.y+(e.y-t.y)*i,this.z=t.z+(e.z-t.z)*i,this.w=t.w+(e.w-t.w)*i,this}equals(t){return t.x===this.x&&t.y===this.y&&t.z===this.z&&t.w===this.w}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this.z=t[e+2],this.w=t[e+3],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t[e+2]=this.z,t[e+3]=this.w,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this.z=t.getZ(e),this.w=t.getW(e),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}},Ra=class extends wi{constructor(t=1,e=1,i={}){super(),this.isRenderTarget=!0,this.width=t,this.height=e,this.depth=1,this.scissor=new Le(0,0,t,e),this.scissorTest=!1,this.viewport=new Le(0,0,t,e);let s={width:t,height:e,depth:1};i=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:Xn,depthBuffer:!0,stencilBuffer:!1,resolveDepthBuffer:!0,resolveStencilBuffer:!0,depthTexture:null,samples:0,count:1},i);let r=new an(s,i.mapping,i.wrapS,i.wrapT,i.magFilter,i.minFilter,i.format,i.type,i.anisotropy,i.colorSpace);r.flipY=!1,r.generateMipmaps=i.generateMipmaps,r.internalFormat=i.internalFormat,this.textures=[];let a=i.count;for(let o=0;o<a;o++)this.textures[o]=r.clone(),this.textures[o].isRenderTargetTexture=!0;this.depthBuffer=i.depthBuffer,this.stencilBuffer=i.stencilBuffer,this.resolveDepthBuffer=i.resolveDepthBuffer,this.resolveStencilBuffer=i.resolveStencilBuffer,this.depthTexture=i.depthTexture,this.samples=i.samples}get texture(){return this.textures[0]}set texture(t){this.textures[0]=t}setSize(t,e,i=1){if(this.width!==t||this.height!==e||this.depth!==i){this.width=t,this.height=e,this.depth=i;for(let s=0,r=this.textures.length;s<r;s++)this.textures[s].image.width=t,this.textures[s].image.height=e,this.textures[s].image.depth=i;this.dispose()}this.viewport.set(0,0,t,e),this.scissor.set(0,0,t,e)}clone(){return new this.constructor().copy(this)}copy(t){this.width=t.width,this.height=t.height,this.depth=t.depth,this.scissor.copy(t.scissor),this.scissorTest=t.scissorTest,this.viewport.copy(t.viewport),this.textures.length=0;for(let i=0,s=t.textures.length;i<s;i++)this.textures[i]=t.textures[i].clone(),this.textures[i].isRenderTargetTexture=!0;let e=Object.assign({},t.texture.image);return this.texture.source=new Zr(e),this.depthBuffer=t.depthBuffer,this.stencilBuffer=t.stencilBuffer,this.resolveDepthBuffer=t.resolveDepthBuffer,this.resolveStencilBuffer=t.resolveStencilBuffer,t.depthTexture!==null&&(this.depthTexture=t.depthTexture.clone()),this.samples=t.samples,this}dispose(){this.dispatchEvent({type:"dispose"})}},ni=class extends Ra{constructor(t=1,e=1,i={}){super(t,e,i),this.isWebGLRenderTarget=!0}},Jr=class extends an{constructor(t=null,e=1,i=1,s=1){super(null),this.isDataArrayTexture=!0,this.image={data:t,width:e,height:i,depth:s},this.magFilter=xn,this.minFilter=xn,this.wrapR=Ji,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}addLayerUpdate(t){this.layerUpdates.add(t)}clearLayerUpdates(){this.layerUpdates.clear()}};var Ca=class extends an{constructor(t=null,e=1,i=1,s=1){super(null),this.isData3DTexture=!0,this.image={data:t,width:e,height:i,depth:s},this.magFilter=xn,this.minFilter=xn,this.wrapR=Ji,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}};var Ti=class{constructor(t=0,e=0,i=0,s=1){this.isQuaternion=!0,this._x=t,this._y=e,this._z=i,this._w=s}static slerpFlat(t,e,i,s,r,a,o){let l=i[s+0],c=i[s+1],h=i[s+2],d=i[s+3],u=r[a+0],f=r[a+1],x=r[a+2],M=r[a+3];if(o===0){t[e+0]=l,t[e+1]=c,t[e+2]=h,t[e+3]=d;return}if(o===1){t[e+0]=u,t[e+1]=f,t[e+2]=x,t[e+3]=M;return}if(d!==M||l!==u||c!==f||h!==x){let m=1-o,p=l*u+c*f+h*x+d*M,S=p>=0?1:-1,E=1-p*p;if(E>Number.EPSILON){let C=Math.sqrt(E),A=Math.atan2(C,p*S);m=Math.sin(m*A)/C,o=Math.sin(o*A)/C}let g=o*S;if(l=l*m+u*g,c=c*m+f*g,h=h*m+x*g,d=d*m+M*g,m===1-o){let C=1/Math.sqrt(l*l+c*c+h*h+d*d);l*=C,c*=C,h*=C,d*=C}}t[e]=l,t[e+1]=c,t[e+2]=h,t[e+3]=d}static multiplyQuaternionsFlat(t,e,i,s,r,a){let o=i[s],l=i[s+1],c=i[s+2],h=i[s+3],d=r[a],u=r[a+1],f=r[a+2],x=r[a+3];return t[e]=o*x+h*d+l*f-c*u,t[e+1]=l*x+h*u+c*d-o*f,t[e+2]=c*x+h*f+o*u-l*d,t[e+3]=h*x-o*d-l*u-c*f,t}get x(){return this._x}set x(t){this._x=t,this._onChangeCallback()}get y(){return this._y}set y(t){this._y=t,this._onChangeCallback()}get z(){return this._z}set z(t){this._z=t,this._onChangeCallback()}get w(){return this._w}set w(t){this._w=t,this._onChangeCallback()}set(t,e,i,s){return this._x=t,this._y=e,this._z=i,this._w=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(t){return this._x=t.x,this._y=t.y,this._z=t.z,this._w=t.w,this._onChangeCallback(),this}setFromEuler(t,e=!0){let i=t._x,s=t._y,r=t._z,a=t._order,o=Math.cos,l=Math.sin,c=o(i/2),h=o(s/2),d=o(r/2),u=l(i/2),f=l(s/2),x=l(r/2);switch(a){case"XYZ":this._x=u*h*d+c*f*x,this._y=c*f*d-u*h*x,this._z=c*h*x+u*f*d,this._w=c*h*d-u*f*x;break;case"YXZ":this._x=u*h*d+c*f*x,this._y=c*f*d-u*h*x,this._z=c*h*x-u*f*d,this._w=c*h*d+u*f*x;break;case"ZXY":this._x=u*h*d-c*f*x,this._y=c*f*d+u*h*x,this._z=c*h*x+u*f*d,this._w=c*h*d-u*f*x;break;case"ZYX":this._x=u*h*d-c*f*x,this._y=c*f*d+u*h*x,this._z=c*h*x-u*f*d,this._w=c*h*d+u*f*x;break;case"YZX":this._x=u*h*d+c*f*x,this._y=c*f*d+u*h*x,this._z=c*h*x-u*f*d,this._w=c*h*d-u*f*x;break;case"XZY":this._x=u*h*d-c*f*x,this._y=c*f*d-u*h*x,this._z=c*h*x+u*f*d,this._w=c*h*d+u*f*x;break;default:console.warn("THREE.Quaternion: .setFromEuler() encountered an unknown order: "+a)}return e===!0&&this._onChangeCallback(),this}setFromAxisAngle(t,e){let i=e/2,s=Math.sin(i);return this._x=t.x*s,this._y=t.y*s,this._z=t.z*s,this._w=Math.cos(i),this._onChangeCallback(),this}setFromRotationMatrix(t){let e=t.elements,i=e[0],s=e[4],r=e[8],a=e[1],o=e[5],l=e[9],c=e[2],h=e[6],d=e[10],u=i+o+d;if(u>0){let f=.5/Math.sqrt(u+1);this._w=.25/f,this._x=(h-l)*f,this._y=(r-c)*f,this._z=(a-s)*f}else if(i>o&&i>d){let f=2*Math.sqrt(1+i-o-d);this._w=(h-l)/f,this._x=.25*f,this._y=(s+a)/f,this._z=(r+c)/f}else if(o>d){let f=2*Math.sqrt(1+o-i-d);this._w=(r-c)/f,this._x=(s+a)/f,this._y=.25*f,this._z=(l+h)/f}else{let f=2*Math.sqrt(1+d-i-o);this._w=(a-s)/f,this._x=(r+c)/f,this._y=(l+h)/f,this._z=.25*f}return this._onChangeCallback(),this}setFromUnitVectors(t,e){let i=t.dot(e)+1;return i<Number.EPSILON?(i=0,Math.abs(t.x)>Math.abs(t.z)?(this._x=-t.y,this._y=t.x,this._z=0,this._w=i):(this._x=0,this._y=-t.z,this._z=t.y,this._w=i)):(this._x=t.y*e.z-t.z*e.y,this._y=t.z*e.x-t.x*e.z,this._z=t.x*e.y-t.y*e.x,this._w=i),this.normalize()}angleTo(t){return 2*Math.acos(Math.abs(ie(this.dot(t),-1,1)))}rotateTowards(t,e){let i=this.angleTo(t);if(i===0)return this;let s=Math.min(1,e/i);return this.slerp(t,s),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(t){return this._x*t._x+this._y*t._y+this._z*t._z+this._w*t._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let t=this.length();return t===0?(this._x=0,this._y=0,this._z=0,this._w=1):(t=1/t,this._x=this._x*t,this._y=this._y*t,this._z=this._z*t,this._w=this._w*t),this._onChangeCallback(),this}multiply(t){return this.multiplyQuaternions(this,t)}premultiply(t){return this.multiplyQuaternions(t,this)}multiplyQuaternions(t,e){let i=t._x,s=t._y,r=t._z,a=t._w,o=e._x,l=e._y,c=e._z,h=e._w;return this._x=i*h+a*o+s*c-r*l,this._y=s*h+a*l+r*o-i*c,this._z=r*h+a*c+i*l-s*o,this._w=a*h-i*o-s*l-r*c,this._onChangeCallback(),this}slerp(t,e){if(e===0)return this;if(e===1)return this.copy(t);let i=this._x,s=this._y,r=this._z,a=this._w,o=a*t._w+i*t._x+s*t._y+r*t._z;if(o<0?(this._w=-t._w,this._x=-t._x,this._y=-t._y,this._z=-t._z,o=-o):this.copy(t),o>=1)return this._w=a,this._x=i,this._y=s,this._z=r,this;let l=1-o*o;if(l<=Number.EPSILON){let f=1-e;return this._w=f*a+e*this._w,this._x=f*i+e*this._x,this._y=f*s+e*this._y,this._z=f*r+e*this._z,this.normalize(),this}let c=Math.sqrt(l),h=Math.atan2(c,o),d=Math.sin((1-e)*h)/c,u=Math.sin(e*h)/c;return this._w=a*d+this._w*u,this._x=i*d+this._x*u,this._y=s*d+this._y*u,this._z=r*d+this._z*u,this._onChangeCallback(),this}slerpQuaternions(t,e,i){return this.copy(t).slerp(e,i)}random(){let t=2*Math.PI*Math.random(),e=2*Math.PI*Math.random(),i=Math.random(),s=Math.sqrt(1-i),r=Math.sqrt(i);return this.set(s*Math.sin(t),s*Math.cos(t),r*Math.sin(e),r*Math.cos(e))}equals(t){return t._x===this._x&&t._y===this._y&&t._z===this._z&&t._w===this._w}fromArray(t,e=0){return this._x=t[e],this._y=t[e+1],this._z=t[e+2],this._w=t[e+3],this._onChangeCallback(),this}toArray(t=[],e=0){return t[e]=this._x,t[e+1]=this._y,t[e+2]=this._z,t[e+3]=this._w,t}fromBufferAttribute(t,e){return this._x=t.getX(e),this._y=t.getY(e),this._z=t.getZ(e),this._w=t.getW(e),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(t){return this._onChangeCallback=t,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}},O=class n{constructor(t=0,e=0,i=0){n.prototype.isVector3=!0,this.x=t,this.y=e,this.z=i}set(t,e,i){return i===void 0&&(i=this.z),this.x=t,this.y=e,this.z=i,this}setScalar(t){return this.x=t,this.y=t,this.z=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setZ(t){return this.z=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;case 2:this.z=e;break;default:throw new Error("index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(t){return this.x=t.x,this.y=t.y,this.z=t.z,this}add(t){return this.x+=t.x,this.y+=t.y,this.z+=t.z,this}addScalar(t){return this.x+=t,this.y+=t,this.z+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this.z=t.z+e.z,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this.z+=t.z*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this.z-=t.z,this}subScalar(t){return this.x-=t,this.y-=t,this.z-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this.z=t.z-e.z,this}multiply(t){return this.x*=t.x,this.y*=t.y,this.z*=t.z,this}multiplyScalar(t){return this.x*=t,this.y*=t,this.z*=t,this}multiplyVectors(t,e){return this.x=t.x*e.x,this.y=t.y*e.y,this.z=t.z*e.z,this}applyEuler(t){return this.applyQuaternion(Ru.setFromEuler(t))}applyAxisAngle(t,e){return this.applyQuaternion(Ru.setFromAxisAngle(t,e))}applyMatrix3(t){let e=this.x,i=this.y,s=this.z,r=t.elements;return this.x=r[0]*e+r[3]*i+r[6]*s,this.y=r[1]*e+r[4]*i+r[7]*s,this.z=r[2]*e+r[5]*i+r[8]*s,this}applyNormalMatrix(t){return this.applyMatrix3(t).normalize()}applyMatrix4(t){let e=this.x,i=this.y,s=this.z,r=t.elements,a=1/(r[3]*e+r[7]*i+r[11]*s+r[15]);return this.x=(r[0]*e+r[4]*i+r[8]*s+r[12])*a,this.y=(r[1]*e+r[5]*i+r[9]*s+r[13])*a,this.z=(r[2]*e+r[6]*i+r[10]*s+r[14])*a,this}applyQuaternion(t){let e=this.x,i=this.y,s=this.z,r=t.x,a=t.y,o=t.z,l=t.w,c=2*(a*s-o*i),h=2*(o*e-r*s),d=2*(r*i-a*e);return this.x=e+l*c+a*d-o*h,this.y=i+l*h+o*c-r*d,this.z=s+l*d+r*h-a*c,this}project(t){return this.applyMatrix4(t.matrixWorldInverse).applyMatrix4(t.projectionMatrix)}unproject(t){return this.applyMatrix4(t.projectionMatrixInverse).applyMatrix4(t.matrixWorld)}transformDirection(t){let e=this.x,i=this.y,s=this.z,r=t.elements;return this.x=r[0]*e+r[4]*i+r[8]*s,this.y=r[1]*e+r[5]*i+r[9]*s,this.z=r[2]*e+r[6]*i+r[10]*s,this.normalize()}divide(t){return this.x/=t.x,this.y/=t.y,this.z/=t.z,this}divideScalar(t){return this.multiplyScalar(1/t)}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this.z=Math.min(this.z,t.z),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this.z=Math.max(this.z,t.z),this}clamp(t,e){return this.x=ie(this.x,t.x,e.x),this.y=ie(this.y,t.y,e.y),this.z=ie(this.z,t.z,e.z),this}clampScalar(t,e){return this.x=ie(this.x,t,e),this.y=ie(this.y,t,e),this.z=ie(this.z,t,e),this}clampLength(t,e){let i=this.length();return this.divideScalar(i||1).multiplyScalar(ie(i,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(t){return this.x*t.x+this.y*t.y+this.z*t.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this.z+=(t.z-this.z)*e,this}lerpVectors(t,e,i){return this.x=t.x+(e.x-t.x)*i,this.y=t.y+(e.y-t.y)*i,this.z=t.z+(e.z-t.z)*i,this}cross(t){return this.crossVectors(this,t)}crossVectors(t,e){let i=t.x,s=t.y,r=t.z,a=e.x,o=e.y,l=e.z;return this.x=s*l-r*o,this.y=r*a-i*l,this.z=i*o-s*a,this}projectOnVector(t){let e=t.lengthSq();if(e===0)return this.set(0,0,0);let i=t.dot(this)/e;return this.copy(t).multiplyScalar(i)}projectOnPlane(t){return _c.copy(this).projectOnVector(t),this.sub(_c)}reflect(t){return this.sub(_c.copy(t).multiplyScalar(2*this.dot(t)))}angleTo(t){let e=Math.sqrt(this.lengthSq()*t.lengthSq());if(e===0)return Math.PI/2;let i=this.dot(t)/e;return Math.acos(ie(i,-1,1))}distanceTo(t){return Math.sqrt(this.distanceToSquared(t))}distanceToSquared(t){let e=this.x-t.x,i=this.y-t.y,s=this.z-t.z;return e*e+i*i+s*s}manhattanDistanceTo(t){return Math.abs(this.x-t.x)+Math.abs(this.y-t.y)+Math.abs(this.z-t.z)}setFromSpherical(t){return this.setFromSphericalCoords(t.radius,t.phi,t.theta)}setFromSphericalCoords(t,e,i){let s=Math.sin(e)*t;return this.x=s*Math.sin(i),this.y=Math.cos(e)*t,this.z=s*Math.cos(i),this}setFromCylindrical(t){return this.setFromCylindricalCoords(t.radius,t.theta,t.y)}setFromCylindricalCoords(t,e,i){return this.x=t*Math.sin(e),this.y=i,this.z=t*Math.cos(e),this}setFromMatrixPosition(t){let e=t.elements;return this.x=e[12],this.y=e[13],this.z=e[14],this}setFromMatrixScale(t){let e=this.setFromMatrixColumn(t,0).length(),i=this.setFromMatrixColumn(t,1).length(),s=this.setFromMatrixColumn(t,2).length();return this.x=e,this.y=i,this.z=s,this}setFromMatrixColumn(t,e){return this.fromArray(t.elements,e*4)}setFromMatrix3Column(t,e){return this.fromArray(t.elements,e*3)}setFromEuler(t){return this.x=t._x,this.y=t._y,this.z=t._z,this}setFromColor(t){return this.x=t.r,this.y=t.g,this.z=t.b,this}equals(t){return t.x===this.x&&t.y===this.y&&t.z===this.z}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this.z=t[e+2],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t[e+2]=this.z,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this.z=t.getZ(e),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){let t=Math.random()*Math.PI*2,e=Math.random()*2-1,i=Math.sqrt(1-e*e);return this.x=i*Math.cos(t),this.y=e,this.z=i*Math.sin(t),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}},_c=new O,Ru=new Ti,ii=class{constructor(t=new O(1/0,1/0,1/0),e=new O(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=t,this.max=e}set(t,e){return this.min.copy(t),this.max.copy(e),this}setFromArray(t){this.makeEmpty();for(let e=0,i=t.length;e<i;e+=3)this.expandByPoint(Gn.fromArray(t,e));return this}setFromBufferAttribute(t){this.makeEmpty();for(let e=0,i=t.count;e<i;e++)this.expandByPoint(Gn.fromBufferAttribute(t,e));return this}setFromPoints(t){this.makeEmpty();for(let e=0,i=t.length;e<i;e++)this.expandByPoint(t[e]);return this}setFromCenterAndSize(t,e){let i=Gn.copy(e).multiplyScalar(.5);return this.min.copy(t).sub(i),this.max.copy(t).add(i),this}setFromObject(t,e=!1){return this.makeEmpty(),this.expandByObject(t,e)}clone(){return new this.constructor().copy(this)}copy(t){return this.min.copy(t.min),this.max.copy(t.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(t){return this.isEmpty()?t.set(0,0,0):t.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(t){return this.isEmpty()?t.set(0,0,0):t.subVectors(this.max,this.min)}expandByPoint(t){return this.min.min(t),this.max.max(t),this}expandByVector(t){return this.min.sub(t),this.max.add(t),this}expandByScalar(t){return this.min.addScalar(-t),this.max.addScalar(t),this}expandByObject(t,e=!1){t.updateWorldMatrix(!1,!1);let i=t.geometry;if(i!==void 0){let r=i.getAttribute("position");if(e===!0&&r!==void 0&&t.isInstancedMesh!==!0)for(let a=0,o=r.count;a<o;a++)t.isMesh===!0?t.getVertexPosition(a,Gn):Gn.fromBufferAttribute(r,a),Gn.applyMatrix4(t.matrixWorld),this.expandByPoint(Gn);else t.boundingBox!==void 0?(t.boundingBox===null&&t.computeBoundingBox(),ta.copy(t.boundingBox)):(i.boundingBox===null&&i.computeBoundingBox(),ta.copy(i.boundingBox)),ta.applyMatrix4(t.matrixWorld),this.union(ta)}let s=t.children;for(let r=0,a=s.length;r<a;r++)this.expandByObject(s[r],e);return this}containsPoint(t){return t.x>=this.min.x&&t.x<=this.max.x&&t.y>=this.min.y&&t.y<=this.max.y&&t.z>=this.min.z&&t.z<=this.max.z}containsBox(t){return this.min.x<=t.min.x&&t.max.x<=this.max.x&&this.min.y<=t.min.y&&t.max.y<=this.max.y&&this.min.z<=t.min.z&&t.max.z<=this.max.z}getParameter(t,e){return e.set((t.x-this.min.x)/(this.max.x-this.min.x),(t.y-this.min.y)/(this.max.y-this.min.y),(t.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(t){return t.max.x>=this.min.x&&t.min.x<=this.max.x&&t.max.y>=this.min.y&&t.min.y<=this.max.y&&t.max.z>=this.min.z&&t.min.z<=this.max.z}intersectsSphere(t){return this.clampPoint(t.center,Gn),Gn.distanceToSquared(t.center)<=t.radius*t.radius}intersectsPlane(t){let e,i;return t.normal.x>0?(e=t.normal.x*this.min.x,i=t.normal.x*this.max.x):(e=t.normal.x*this.max.x,i=t.normal.x*this.min.x),t.normal.y>0?(e+=t.normal.y*this.min.y,i+=t.normal.y*this.max.y):(e+=t.normal.y*this.max.y,i+=t.normal.y*this.min.y),t.normal.z>0?(e+=t.normal.z*this.min.z,i+=t.normal.z*this.max.z):(e+=t.normal.z*this.max.z,i+=t.normal.z*this.min.z),e<=-t.constant&&i>=-t.constant}intersectsTriangle(t){if(this.isEmpty())return!1;this.getCenter(Hr),ea.subVectors(this.max,Hr),Js.subVectors(t.a,Hr),Ks.subVectors(t.b,Hr),Qs.subVectors(t.c,Hr),Vi.subVectors(Ks,Js),Wi.subVectors(Qs,Ks),ys.subVectors(Js,Qs);let e=[0,-Vi.z,Vi.y,0,-Wi.z,Wi.y,0,-ys.z,ys.y,Vi.z,0,-Vi.x,Wi.z,0,-Wi.x,ys.z,0,-ys.x,-Vi.y,Vi.x,0,-Wi.y,Wi.x,0,-ys.y,ys.x,0];return!vc(e,Js,Ks,Qs,ea)||(e=[1,0,0,0,1,0,0,0,1],!vc(e,Js,Ks,Qs,ea))?!1:(na.crossVectors(Vi,Wi),e=[na.x,na.y,na.z],vc(e,Js,Ks,Qs,ea))}clampPoint(t,e){return e.copy(t).clamp(this.min,this.max)}distanceToPoint(t){return this.clampPoint(t,Gn).distanceTo(t)}getBoundingSphere(t){return this.isEmpty()?t.makeEmpty():(this.getCenter(t.center),t.radius=this.getSize(Gn).length()*.5),t}intersect(t){return this.min.max(t.min),this.max.min(t.max),this.isEmpty()&&this.makeEmpty(),this}union(t){return this.min.min(t.min),this.max.max(t.max),this}applyMatrix4(t){return this.isEmpty()?this:(gi[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(t),gi[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(t),gi[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(t),gi[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(t),gi[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(t),gi[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(t),gi[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(t),gi[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(t),this.setFromPoints(gi),this)}translate(t){return this.min.add(t),this.max.add(t),this}equals(t){return t.min.equals(this.min)&&t.max.equals(this.max)}},gi=[new O,new O,new O,new O,new O,new O,new O,new O],Gn=new O,ta=new ii,Js=new O,Ks=new O,Qs=new O,Vi=new O,Wi=new O,ys=new O,Hr=new O,ea=new O,na=new O,_s=new O;function vc(n,t,e,i,s){for(let r=0,a=n.length-3;r<=a;r+=3){_s.fromArray(n,r);let o=s.x*Math.abs(_s.x)+s.y*Math.abs(_s.y)+s.z*Math.abs(_s.z),l=t.dot(_s),c=e.dot(_s),h=i.dot(_s);if(Math.max(-Math.max(l,c,h),Math.min(l,c,h))>o)return!1}return!0}var Ap=new ii,Br=new O,Mc=new O,Qi=class{constructor(t=new O,e=-1){this.isSphere=!0,this.center=t,this.radius=e}set(t,e){return this.center.copy(t),this.radius=e,this}setFromPoints(t,e){let i=this.center;e!==void 0?i.copy(e):Ap.setFromPoints(t).getCenter(i);let s=0;for(let r=0,a=t.length;r<a;r++)s=Math.max(s,i.distanceToSquared(t[r]));return this.radius=Math.sqrt(s),this}copy(t){return this.center.copy(t.center),this.radius=t.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(t){return t.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(t){return t.distanceTo(this.center)-this.radius}intersectsSphere(t){let e=this.radius+t.radius;return t.center.distanceToSquared(this.center)<=e*e}intersectsBox(t){return t.intersectsSphere(this)}intersectsPlane(t){return Math.abs(t.distanceToPoint(this.center))<=this.radius}clampPoint(t,e){let i=this.center.distanceToSquared(t);return e.copy(t),i>this.radius*this.radius&&(e.sub(this.center).normalize(),e.multiplyScalar(this.radius).add(this.center)),e}getBoundingBox(t){return this.isEmpty()?(t.makeEmpty(),t):(t.set(this.center,this.center),t.expandByScalar(this.radius),t)}applyMatrix4(t){return this.center.applyMatrix4(t),this.radius=this.radius*t.getMaxScaleOnAxis(),this}translate(t){return this.center.add(t),this}expandByPoint(t){if(this.isEmpty())return this.center.copy(t),this.radius=0,this;Br.subVectors(t,this.center);let e=Br.lengthSq();if(e>this.radius*this.radius){let i=Math.sqrt(e),s=(i-this.radius)*.5;this.center.addScaledVector(Br,s/i),this.radius+=s}return this}union(t){return t.isEmpty()?this:this.isEmpty()?(this.copy(t),this):(this.center.equals(t.center)===!0?this.radius=Math.max(this.radius,t.radius):(Mc.subVectors(t.center,this.center).setLength(t.radius),this.expandByPoint(Br.copy(t.center).add(Mc)),this.expandByPoint(Br.copy(t.center).sub(Mc))),this)}equals(t){return t.center.equals(this.center)&&t.radius===this.radius}clone(){return new this.constructor().copy(this)}},xi=new O,Ec=new O,ia=new O,Xi=new O,Sc=new O,sa=new O,wc=new O,Pa=class{constructor(t=new O,e=new O(0,0,-1)){this.origin=t,this.direction=e}set(t,e){return this.origin.copy(t),this.direction.copy(e),this}copy(t){return this.origin.copy(t.origin),this.direction.copy(t.direction),this}at(t,e){return e.copy(this.origin).addScaledVector(this.direction,t)}lookAt(t){return this.direction.copy(t).sub(this.origin).normalize(),this}recast(t){return this.origin.copy(this.at(t,xi)),this}closestPointToPoint(t,e){e.subVectors(t,this.origin);let i=e.dot(this.direction);return i<0?e.copy(this.origin):e.copy(this.origin).addScaledVector(this.direction,i)}distanceToPoint(t){return Math.sqrt(this.distanceSqToPoint(t))}distanceSqToPoint(t){let e=xi.subVectors(t,this.origin).dot(this.direction);return e<0?this.origin.distanceToSquared(t):(xi.copy(this.origin).addScaledVector(this.direction,e),xi.distanceToSquared(t))}distanceSqToSegment(t,e,i,s){Ec.copy(t).add(e).multiplyScalar(.5),ia.copy(e).sub(t).normalize(),Xi.copy(this.origin).sub(Ec);let r=t.distanceTo(e)*.5,a=-this.direction.dot(ia),o=Xi.dot(this.direction),l=-Xi.dot(ia),c=Xi.lengthSq(),h=Math.abs(1-a*a),d,u,f,x;if(h>0)if(d=a*l-o,u=a*o-l,x=r*h,d>=0)if(u>=-x)if(u<=x){let M=1/h;d*=M,u*=M,f=d*(d+a*u+2*o)+u*(a*d+u+2*l)+c}else u=r,d=Math.max(0,-(a*u+o)),f=-d*d+u*(u+2*l)+c;else u=-r,d=Math.max(0,-(a*u+o)),f=-d*d+u*(u+2*l)+c;else u<=-x?(d=Math.max(0,-(-a*r+o)),u=d>0?-r:Math.min(Math.max(-r,-l),r),f=-d*d+u*(u+2*l)+c):u<=x?(d=0,u=Math.min(Math.max(-r,-l),r),f=u*(u+2*l)+c):(d=Math.max(0,-(a*r+o)),u=d>0?r:Math.min(Math.max(-r,-l),r),f=-d*d+u*(u+2*l)+c);else u=a>0?-r:r,d=Math.max(0,-(a*u+o)),f=-d*d+u*(u+2*l)+c;return i&&i.copy(this.origin).addScaledVector(this.direction,d),s&&s.copy(Ec).addScaledVector(ia,u),f}intersectSphere(t,e){xi.subVectors(t.center,this.origin);let i=xi.dot(this.direction),s=xi.dot(xi)-i*i,r=t.radius*t.radius;if(s>r)return null;let a=Math.sqrt(r-s),o=i-a,l=i+a;return l<0?null:o<0?this.at(l,e):this.at(o,e)}intersectsSphere(t){return this.distanceSqToPoint(t.center)<=t.radius*t.radius}distanceToPlane(t){let e=t.normal.dot(this.direction);if(e===0)return t.distanceToPoint(this.origin)===0?0:null;let i=-(this.origin.dot(t.normal)+t.constant)/e;return i>=0?i:null}intersectPlane(t,e){let i=this.distanceToPlane(t);return i===null?null:this.at(i,e)}intersectsPlane(t){let e=t.distanceToPoint(this.origin);return e===0||t.normal.dot(this.direction)*e<0}intersectBox(t,e){let i,s,r,a,o,l,c=1/this.direction.x,h=1/this.direction.y,d=1/this.direction.z,u=this.origin;return c>=0?(i=(t.min.x-u.x)*c,s=(t.max.x-u.x)*c):(i=(t.max.x-u.x)*c,s=(t.min.x-u.x)*c),h>=0?(r=(t.min.y-u.y)*h,a=(t.max.y-u.y)*h):(r=(t.max.y-u.y)*h,a=(t.min.y-u.y)*h),i>a||r>s||((r>i||isNaN(i))&&(i=r),(a<s||isNaN(s))&&(s=a),d>=0?(o=(t.min.z-u.z)*d,l=(t.max.z-u.z)*d):(o=(t.max.z-u.z)*d,l=(t.min.z-u.z)*d),i>l||o>s)||((o>i||i!==i)&&(i=o),(l<s||s!==s)&&(s=l),s<0)?null:this.at(i>=0?i:s,e)}intersectsBox(t){return this.intersectBox(t,xi)!==null}intersectTriangle(t,e,i,s,r){Sc.subVectors(e,t),sa.subVectors(i,t),wc.crossVectors(Sc,sa);let a=this.direction.dot(wc),o;if(a>0){if(s)return null;o=1}else if(a<0)o=-1,a=-a;else return null;Xi.subVectors(this.origin,t);let l=o*this.direction.dot(sa.crossVectors(Xi,sa));if(l<0)return null;let c=o*this.direction.dot(Sc.cross(Xi));if(c<0||l+c>a)return null;let h=-o*Xi.dot(wc);return h<0?null:this.at(h/a,r)}applyMatrix4(t){return this.origin.applyMatrix4(t),this.direction.transformDirection(t),this}equals(t){return t.origin.equals(this.origin)&&t.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}},be=class n{constructor(t,e,i,s,r,a,o,l,c,h,d,u,f,x,M,m){n.prototype.isMatrix4=!0,this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],t!==void 0&&this.set(t,e,i,s,r,a,o,l,c,h,d,u,f,x,M,m)}set(t,e,i,s,r,a,o,l,c,h,d,u,f,x,M,m){let p=this.elements;return p[0]=t,p[4]=e,p[8]=i,p[12]=s,p[1]=r,p[5]=a,p[9]=o,p[13]=l,p[2]=c,p[6]=h,p[10]=d,p[14]=u,p[3]=f,p[7]=x,p[11]=M,p[15]=m,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new n().fromArray(this.elements)}copy(t){let e=this.elements,i=t.elements;return e[0]=i[0],e[1]=i[1],e[2]=i[2],e[3]=i[3],e[4]=i[4],e[5]=i[5],e[6]=i[6],e[7]=i[7],e[8]=i[8],e[9]=i[9],e[10]=i[10],e[11]=i[11],e[12]=i[12],e[13]=i[13],e[14]=i[14],e[15]=i[15],this}copyPosition(t){let e=this.elements,i=t.elements;return e[12]=i[12],e[13]=i[13],e[14]=i[14],this}setFromMatrix3(t){let e=t.elements;return this.set(e[0],e[3],e[6],0,e[1],e[4],e[7],0,e[2],e[5],e[8],0,0,0,0,1),this}extractBasis(t,e,i){return t.setFromMatrixColumn(this,0),e.setFromMatrixColumn(this,1),i.setFromMatrixColumn(this,2),this}makeBasis(t,e,i){return this.set(t.x,e.x,i.x,0,t.y,e.y,i.y,0,t.z,e.z,i.z,0,0,0,0,1),this}extractRotation(t){let e=this.elements,i=t.elements,s=1/js.setFromMatrixColumn(t,0).length(),r=1/js.setFromMatrixColumn(t,1).length(),a=1/js.setFromMatrixColumn(t,2).length();return e[0]=i[0]*s,e[1]=i[1]*s,e[2]=i[2]*s,e[3]=0,e[4]=i[4]*r,e[5]=i[5]*r,e[6]=i[6]*r,e[7]=0,e[8]=i[8]*a,e[9]=i[9]*a,e[10]=i[10]*a,e[11]=0,e[12]=0,e[13]=0,e[14]=0,e[15]=1,this}makeRotationFromEuler(t){let e=this.elements,i=t.x,s=t.y,r=t.z,a=Math.cos(i),o=Math.sin(i),l=Math.cos(s),c=Math.sin(s),h=Math.cos(r),d=Math.sin(r);if(t.order==="XYZ"){let u=a*h,f=a*d,x=o*h,M=o*d;e[0]=l*h,e[4]=-l*d,e[8]=c,e[1]=f+x*c,e[5]=u-M*c,e[9]=-o*l,e[2]=M-u*c,e[6]=x+f*c,e[10]=a*l}else if(t.order==="YXZ"){let u=l*h,f=l*d,x=c*h,M=c*d;e[0]=u+M*o,e[4]=x*o-f,e[8]=a*c,e[1]=a*d,e[5]=a*h,e[9]=-o,e[2]=f*o-x,e[6]=M+u*o,e[10]=a*l}else if(t.order==="ZXY"){let u=l*h,f=l*d,x=c*h,M=c*d;e[0]=u-M*o,e[4]=-a*d,e[8]=x+f*o,e[1]=f+x*o,e[5]=a*h,e[9]=M-u*o,e[2]=-a*c,e[6]=o,e[10]=a*l}else if(t.order==="ZYX"){let u=a*h,f=a*d,x=o*h,M=o*d;e[0]=l*h,e[4]=x*c-f,e[8]=u*c+M,e[1]=l*d,e[5]=M*c+u,e[9]=f*c-x,e[2]=-c,e[6]=o*l,e[10]=a*l}else if(t.order==="YZX"){let u=a*l,f=a*c,x=o*l,M=o*c;e[0]=l*h,e[4]=M-u*d,e[8]=x*d+f,e[1]=d,e[5]=a*h,e[9]=-o*h,e[2]=-c*h,e[6]=f*d+x,e[10]=u-M*d}else if(t.order==="XZY"){let u=a*l,f=a*c,x=o*l,M=o*c;e[0]=l*h,e[4]=-d,e[8]=c*h,e[1]=u*d+M,e[5]=a*h,e[9]=f*d-x,e[2]=x*d-f,e[6]=o*h,e[10]=M*d+u}return e[3]=0,e[7]=0,e[11]=0,e[12]=0,e[13]=0,e[14]=0,e[15]=1,this}makeRotationFromQuaternion(t){return this.compose(Rp,t,Cp)}lookAt(t,e,i){let s=this.elements;return wn.subVectors(t,e),wn.lengthSq()===0&&(wn.z=1),wn.normalize(),qi.crossVectors(i,wn),qi.lengthSq()===0&&(Math.abs(i.z)===1?wn.x+=1e-4:wn.z+=1e-4,wn.normalize(),qi.crossVectors(i,wn)),qi.normalize(),ra.crossVectors(wn,qi),s[0]=qi.x,s[4]=ra.x,s[8]=wn.x,s[1]=qi.y,s[5]=ra.y,s[9]=wn.y,s[2]=qi.z,s[6]=ra.z,s[10]=wn.z,this}multiply(t){return this.multiplyMatrices(this,t)}premultiply(t){return this.multiplyMatrices(t,this)}multiplyMatrices(t,e){let i=t.elements,s=e.elements,r=this.elements,a=i[0],o=i[4],l=i[8],c=i[12],h=i[1],d=i[5],u=i[9],f=i[13],x=i[2],M=i[6],m=i[10],p=i[14],S=i[3],E=i[7],g=i[11],C=i[15],A=s[0],_=s[4],T=s[8],v=s[12],y=s[1],w=s[5],P=s[9],D=s[13],N=s[2],H=s[6],U=s[10],k=s[14],F=s[3],G=s[7],q=s[11],et=s[15];return r[0]=a*A+o*y+l*N+c*F,r[4]=a*_+o*w+l*H+c*G,r[8]=a*T+o*P+l*U+c*q,r[12]=a*v+o*D+l*k+c*et,r[1]=h*A+d*y+u*N+f*F,r[5]=h*_+d*w+u*H+f*G,r[9]=h*T+d*P+u*U+f*q,r[13]=h*v+d*D+u*k+f*et,r[2]=x*A+M*y+m*N+p*F,r[6]=x*_+M*w+m*H+p*G,r[10]=x*T+M*P+m*U+p*q,r[14]=x*v+M*D+m*k+p*et,r[3]=S*A+E*y+g*N+C*F,r[7]=S*_+E*w+g*H+C*G,r[11]=S*T+E*P+g*U+C*q,r[15]=S*v+E*D+g*k+C*et,this}multiplyScalar(t){let e=this.elements;return e[0]*=t,e[4]*=t,e[8]*=t,e[12]*=t,e[1]*=t,e[5]*=t,e[9]*=t,e[13]*=t,e[2]*=t,e[6]*=t,e[10]*=t,e[14]*=t,e[3]*=t,e[7]*=t,e[11]*=t,e[15]*=t,this}determinant(){let t=this.elements,e=t[0],i=t[4],s=t[8],r=t[12],a=t[1],o=t[5],l=t[9],c=t[13],h=t[2],d=t[6],u=t[10],f=t[14],x=t[3],M=t[7],m=t[11],p=t[15];return x*(+r*l*d-s*c*d-r*o*u+i*c*u+s*o*f-i*l*f)+M*(+e*l*f-e*c*u+r*a*u-s*a*f+s*c*h-r*l*h)+m*(+e*c*d-e*o*f-r*a*d+i*a*f+r*o*h-i*c*h)+p*(-s*o*h-e*l*d+e*o*u+s*a*d-i*a*u+i*l*h)}transpose(){let t=this.elements,e;return e=t[1],t[1]=t[4],t[4]=e,e=t[2],t[2]=t[8],t[8]=e,e=t[6],t[6]=t[9],t[9]=e,e=t[3],t[3]=t[12],t[12]=e,e=t[7],t[7]=t[13],t[13]=e,e=t[11],t[11]=t[14],t[14]=e,this}setPosition(t,e,i){let s=this.elements;return t.isVector3?(s[12]=t.x,s[13]=t.y,s[14]=t.z):(s[12]=t,s[13]=e,s[14]=i),this}invert(){let t=this.elements,e=t[0],i=t[1],s=t[2],r=t[3],a=t[4],o=t[5],l=t[6],c=t[7],h=t[8],d=t[9],u=t[10],f=t[11],x=t[12],M=t[13],m=t[14],p=t[15],S=d*m*c-M*u*c+M*l*f-o*m*f-d*l*p+o*u*p,E=x*u*c-h*m*c-x*l*f+a*m*f+h*l*p-a*u*p,g=h*M*c-x*d*c+x*o*f-a*M*f-h*o*p+a*d*p,C=x*d*l-h*M*l-x*o*u+a*M*u+h*o*m-a*d*m,A=e*S+i*E+s*g+r*C;if(A===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);let _=1/A;return t[0]=S*_,t[1]=(M*u*r-d*m*r-M*s*f+i*m*f+d*s*p-i*u*p)*_,t[2]=(o*m*r-M*l*r+M*s*c-i*m*c-o*s*p+i*l*p)*_,t[3]=(d*l*r-o*u*r-d*s*c+i*u*c+o*s*f-i*l*f)*_,t[4]=E*_,t[5]=(h*m*r-x*u*r+x*s*f-e*m*f-h*s*p+e*u*p)*_,t[6]=(x*l*r-a*m*r-x*s*c+e*m*c+a*s*p-e*l*p)*_,t[7]=(a*u*r-h*l*r+h*s*c-e*u*c-a*s*f+e*l*f)*_,t[8]=g*_,t[9]=(x*d*r-h*M*r-x*i*f+e*M*f+h*i*p-e*d*p)*_,t[10]=(a*M*r-x*o*r+x*i*c-e*M*c-a*i*p+e*o*p)*_,t[11]=(h*o*r-a*d*r-h*i*c+e*d*c+a*i*f-e*o*f)*_,t[12]=C*_,t[13]=(h*M*s-x*d*s+x*i*u-e*M*u-h*i*m+e*d*m)*_,t[14]=(x*o*s-a*M*s-x*i*l+e*M*l+a*i*m-e*o*m)*_,t[15]=(a*d*s-h*o*s+h*i*l-e*d*l-a*i*u+e*o*u)*_,this}scale(t){let e=this.elements,i=t.x,s=t.y,r=t.z;return e[0]*=i,e[4]*=s,e[8]*=r,e[1]*=i,e[5]*=s,e[9]*=r,e[2]*=i,e[6]*=s,e[10]*=r,e[3]*=i,e[7]*=s,e[11]*=r,this}getMaxScaleOnAxis(){let t=this.elements,e=t[0]*t[0]+t[1]*t[1]+t[2]*t[2],i=t[4]*t[4]+t[5]*t[5]+t[6]*t[6],s=t[8]*t[8]+t[9]*t[9]+t[10]*t[10];return Math.sqrt(Math.max(e,i,s))}makeTranslation(t,e,i){return t.isVector3?this.set(1,0,0,t.x,0,1,0,t.y,0,0,1,t.z,0,0,0,1):this.set(1,0,0,t,0,1,0,e,0,0,1,i,0,0,0,1),this}makeRotationX(t){let e=Math.cos(t),i=Math.sin(t);return this.set(1,0,0,0,0,e,-i,0,0,i,e,0,0,0,0,1),this}makeRotationY(t){let e=Math.cos(t),i=Math.sin(t);return this.set(e,0,i,0,0,1,0,0,-i,0,e,0,0,0,0,1),this}makeRotationZ(t){let e=Math.cos(t),i=Math.sin(t);return this.set(e,-i,0,0,i,e,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(t,e){let i=Math.cos(e),s=Math.sin(e),r=1-i,a=t.x,o=t.y,l=t.z,c=r*a,h=r*o;return this.set(c*a+i,c*o-s*l,c*l+s*o,0,c*o+s*l,h*o+i,h*l-s*a,0,c*l-s*o,h*l+s*a,r*l*l+i,0,0,0,0,1),this}makeScale(t,e,i){return this.set(t,0,0,0,0,e,0,0,0,0,i,0,0,0,0,1),this}makeShear(t,e,i,s,r,a){return this.set(1,i,r,0,t,1,a,0,e,s,1,0,0,0,0,1),this}compose(t,e,i){let s=this.elements,r=e._x,a=e._y,o=e._z,l=e._w,c=r+r,h=a+a,d=o+o,u=r*c,f=r*h,x=r*d,M=a*h,m=a*d,p=o*d,S=l*c,E=l*h,g=l*d,C=i.x,A=i.y,_=i.z;return s[0]=(1-(M+p))*C,s[1]=(f+g)*C,s[2]=(x-E)*C,s[3]=0,s[4]=(f-g)*A,s[5]=(1-(u+p))*A,s[6]=(m+S)*A,s[7]=0,s[8]=(x+E)*_,s[9]=(m-S)*_,s[10]=(1-(u+M))*_,s[11]=0,s[12]=t.x,s[13]=t.y,s[14]=t.z,s[15]=1,this}decompose(t,e,i){let s=this.elements,r=js.set(s[0],s[1],s[2]).length(),a=js.set(s[4],s[5],s[6]).length(),o=js.set(s[8],s[9],s[10]).length();this.determinant()<0&&(r=-r),t.x=s[12],t.y=s[13],t.z=s[14],Vn.copy(this);let c=1/r,h=1/a,d=1/o;return Vn.elements[0]*=c,Vn.elements[1]*=c,Vn.elements[2]*=c,Vn.elements[4]*=h,Vn.elements[5]*=h,Vn.elements[6]*=h,Vn.elements[8]*=d,Vn.elements[9]*=d,Vn.elements[10]*=d,e.setFromRotationMatrix(Vn),i.x=r,i.y=a,i.z=o,this}makePerspective(t,e,i,s,r,a,o=ei){let l=this.elements,c=2*r/(e-t),h=2*r/(i-s),d=(e+t)/(e-t),u=(i+s)/(i-s),f,x;if(o===ei)f=-(a+r)/(a-r),x=-2*a*r/(a-r);else if(o===$r)f=-a/(a-r),x=-a*r/(a-r);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+o);return l[0]=c,l[4]=0,l[8]=d,l[12]=0,l[1]=0,l[5]=h,l[9]=u,l[13]=0,l[2]=0,l[6]=0,l[10]=f,l[14]=x,l[3]=0,l[7]=0,l[11]=-1,l[15]=0,this}makeOrthographic(t,e,i,s,r,a,o=ei){let l=this.elements,c=1/(e-t),h=1/(i-s),d=1/(a-r),u=(e+t)*c,f=(i+s)*h,x,M;if(o===ei)x=(a+r)*d,M=-2*d;else if(o===$r)x=r*d,M=-1*d;else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+o);return l[0]=2*c,l[4]=0,l[8]=0,l[12]=-u,l[1]=0,l[5]=2*h,l[9]=0,l[13]=-f,l[2]=0,l[6]=0,l[10]=M,l[14]=-x,l[3]=0,l[7]=0,l[11]=0,l[15]=1,this}equals(t){let e=this.elements,i=t.elements;for(let s=0;s<16;s++)if(e[s]!==i[s])return!1;return!0}fromArray(t,e=0){for(let i=0;i<16;i++)this.elements[i]=t[i+e];return this}toArray(t=[],e=0){let i=this.elements;return t[e]=i[0],t[e+1]=i[1],t[e+2]=i[2],t[e+3]=i[3],t[e+4]=i[4],t[e+5]=i[5],t[e+6]=i[6],t[e+7]=i[7],t[e+8]=i[8],t[e+9]=i[9],t[e+10]=i[10],t[e+11]=i[11],t[e+12]=i[12],t[e+13]=i[13],t[e+14]=i[14],t[e+15]=i[15],t}},js=new O,Vn=new be,Rp=new O(0,0,0),Cp=new O(1,1,1),qi=new O,ra=new O,wn=new O,Cu=new be,Pu=new Ti,Ln=class n{constructor(t=0,e=0,i=0,s=n.DEFAULT_ORDER){this.isEuler=!0,this._x=t,this._y=e,this._z=i,this._order=s}get x(){return this._x}set x(t){this._x=t,this._onChangeCallback()}get y(){return this._y}set y(t){this._y=t,this._onChangeCallback()}get z(){return this._z}set z(t){this._z=t,this._onChangeCallback()}get order(){return this._order}set order(t){this._order=t,this._onChangeCallback()}set(t,e,i,s=this._order){return this._x=t,this._y=e,this._z=i,this._order=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(t){return this._x=t._x,this._y=t._y,this._z=t._z,this._order=t._order,this._onChangeCallback(),this}setFromRotationMatrix(t,e=this._order,i=!0){let s=t.elements,r=s[0],a=s[4],o=s[8],l=s[1],c=s[5],h=s[9],d=s[2],u=s[6],f=s[10];switch(e){case"XYZ":this._y=Math.asin(ie(o,-1,1)),Math.abs(o)<.9999999?(this._x=Math.atan2(-h,f),this._z=Math.atan2(-a,r)):(this._x=Math.atan2(u,c),this._z=0);break;case"YXZ":this._x=Math.asin(-ie(h,-1,1)),Math.abs(h)<.9999999?(this._y=Math.atan2(o,f),this._z=Math.atan2(l,c)):(this._y=Math.atan2(-d,r),this._z=0);break;case"ZXY":this._x=Math.asin(ie(u,-1,1)),Math.abs(u)<.9999999?(this._y=Math.atan2(-d,f),this._z=Math.atan2(-a,c)):(this._y=0,this._z=Math.atan2(l,r));break;case"ZYX":this._y=Math.asin(-ie(d,-1,1)),Math.abs(d)<.9999999?(this._x=Math.atan2(u,f),this._z=Math.atan2(l,r)):(this._x=0,this._z=Math.atan2(-a,c));break;case"YZX":this._z=Math.asin(ie(l,-1,1)),Math.abs(l)<.9999999?(this._x=Math.atan2(-h,c),this._y=Math.atan2(-d,r)):(this._x=0,this._y=Math.atan2(o,f));break;case"XZY":this._z=Math.asin(-ie(a,-1,1)),Math.abs(a)<.9999999?(this._x=Math.atan2(u,c),this._y=Math.atan2(o,r)):(this._x=Math.atan2(-h,f),this._y=0);break;default:console.warn("THREE.Euler: .setFromRotationMatrix() encountered an unknown order: "+e)}return this._order=e,i===!0&&this._onChangeCallback(),this}setFromQuaternion(t,e,i){return Cu.makeRotationFromQuaternion(t),this.setFromRotationMatrix(Cu,e,i)}setFromVector3(t,e=this._order){return this.set(t.x,t.y,t.z,e)}reorder(t){return Pu.setFromEuler(this),this.setFromQuaternion(Pu,t)}equals(t){return t._x===this._x&&t._y===this._y&&t._z===this._z&&t._order===this._order}fromArray(t){return this._x=t[0],this._y=t[1],this._z=t[2],t[3]!==void 0&&(this._order=t[3]),this._onChangeCallback(),this}toArray(t=[],e=0){return t[e]=this._x,t[e+1]=this._y,t[e+2]=this._z,t[e+3]=this._order,t}_onChange(t){return this._onChangeCallback=t,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}};Ln.DEFAULT_ORDER="XYZ";var Kr=class{constructor(){this.mask=1}set(t){this.mask=(1<<t|0)>>>0}enable(t){this.mask|=1<<t|0}enableAll(){this.mask=-1}toggle(t){this.mask^=1<<t|0}disable(t){this.mask&=~(1<<t|0)}disableAll(){this.mask=0}test(t){return(this.mask&t.mask)!==0}isEnabled(t){return(this.mask&(1<<t|0))!==0}},Pp=0,Iu=new O,tr=new Ti,yi=new be,oa=new O,kr=new O,Ip=new O,Lp=new Ti,Lu=new O(1,0,0),Du=new O(0,1,0),Uu=new O(0,0,1),Nu={type:"added"},Dp={type:"removed"},er={type:"childadded",child:null},Tc={type:"childremoved",child:null},Oe=class n extends wi{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:Pp++}),this.uuid=Mr(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=n.DEFAULT_UP.clone();let t=new O,e=new Ln,i=new Ti,s=new O(1,1,1);function r(){i.setFromEuler(e,!1)}function a(){e.setFromQuaternion(i,void 0,!1)}e._onChange(r),i._onChange(a),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:t},rotation:{configurable:!0,enumerable:!0,value:e},quaternion:{configurable:!0,enumerable:!0,value:i},scale:{configurable:!0,enumerable:!0,value:s},modelViewMatrix:{value:new be},normalMatrix:{value:new Qt}}),this.matrix=new be,this.matrixWorld=new be,this.matrixAutoUpdate=n.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=n.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new Kr,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.userData={}}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(t){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(t),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(t){return this.quaternion.premultiply(t),this}setRotationFromAxisAngle(t,e){this.quaternion.setFromAxisAngle(t,e)}setRotationFromEuler(t){this.quaternion.setFromEuler(t,!0)}setRotationFromMatrix(t){this.quaternion.setFromRotationMatrix(t)}setRotationFromQuaternion(t){this.quaternion.copy(t)}rotateOnAxis(t,e){return tr.setFromAxisAngle(t,e),this.quaternion.multiply(tr),this}rotateOnWorldAxis(t,e){return tr.setFromAxisAngle(t,e),this.quaternion.premultiply(tr),this}rotateX(t){return this.rotateOnAxis(Lu,t)}rotateY(t){return this.rotateOnAxis(Du,t)}rotateZ(t){return this.rotateOnAxis(Uu,t)}translateOnAxis(t,e){return Iu.copy(t).applyQuaternion(this.quaternion),this.position.add(Iu.multiplyScalar(e)),this}translateX(t){return this.translateOnAxis(Lu,t)}translateY(t){return this.translateOnAxis(Du,t)}translateZ(t){return this.translateOnAxis(Uu,t)}localToWorld(t){return this.updateWorldMatrix(!0,!1),t.applyMatrix4(this.matrixWorld)}worldToLocal(t){return this.updateWorldMatrix(!0,!1),t.applyMatrix4(yi.copy(this.matrixWorld).invert())}lookAt(t,e,i){t.isVector3?oa.copy(t):oa.set(t,e,i);let s=this.parent;this.updateWorldMatrix(!0,!1),kr.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?yi.lookAt(kr,oa,this.up):yi.lookAt(oa,kr,this.up),this.quaternion.setFromRotationMatrix(yi),s&&(yi.extractRotation(s.matrixWorld),tr.setFromRotationMatrix(yi),this.quaternion.premultiply(tr.invert()))}add(t){if(arguments.length>1){for(let e=0;e<arguments.length;e++)this.add(arguments[e]);return this}return t===this?(console.error("THREE.Object3D.add: object can't be added as a child of itself.",t),this):(t&&t.isObject3D?(t.removeFromParent(),t.parent=this,this.children.push(t),t.dispatchEvent(Nu),er.child=t,this.dispatchEvent(er),er.child=null):console.error("THREE.Object3D.add: object not an instance of THREE.Object3D.",t),this)}remove(t){if(arguments.length>1){for(let i=0;i<arguments.length;i++)this.remove(arguments[i]);return this}let e=this.children.indexOf(t);return e!==-1&&(t.parent=null,this.children.splice(e,1),t.dispatchEvent(Dp),Tc.child=t,this.dispatchEvent(Tc),Tc.child=null),this}removeFromParent(){let t=this.parent;return t!==null&&t.remove(this),this}clear(){return this.remove(...this.children)}attach(t){return this.updateWorldMatrix(!0,!1),yi.copy(this.matrixWorld).invert(),t.parent!==null&&(t.parent.updateWorldMatrix(!0,!1),yi.multiply(t.parent.matrixWorld)),t.applyMatrix4(yi),t.removeFromParent(),t.parent=this,this.children.push(t),t.updateWorldMatrix(!1,!0),t.dispatchEvent(Nu),er.child=t,this.dispatchEvent(er),er.child=null,this}getObjectById(t){return this.getObjectByProperty("id",t)}getObjectByName(t){return this.getObjectByProperty("name",t)}getObjectByProperty(t,e){if(this[t]===e)return this;for(let i=0,s=this.children.length;i<s;i++){let a=this.children[i].getObjectByProperty(t,e);if(a!==void 0)return a}}getObjectsByProperty(t,e,i=[]){this[t]===e&&i.push(this);let s=this.children;for(let r=0,a=s.length;r<a;r++)s[r].getObjectsByProperty(t,e,i);return i}getWorldPosition(t){return this.updateWorldMatrix(!0,!1),t.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(t){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(kr,t,Ip),t}getWorldScale(t){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(kr,Lp,t),t}getWorldDirection(t){this.updateWorldMatrix(!0,!1);let e=this.matrixWorld.elements;return t.set(e[8],e[9],e[10]).normalize()}raycast(){}traverse(t){t(this);let e=this.children;for(let i=0,s=e.length;i<s;i++)e[i].traverse(t)}traverseVisible(t){if(this.visible===!1)return;t(this);let e=this.children;for(let i=0,s=e.length;i<s;i++)e[i].traverseVisible(t)}traverseAncestors(t){let e=this.parent;e!==null&&(t(e),e.traverseAncestors(t))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale),this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(t){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||t)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,t=!0);let e=this.children;for(let i=0,s=e.length;i<s;i++)e[i].updateMatrixWorld(t)}updateWorldMatrix(t,e){let i=this.parent;if(t===!0&&i!==null&&i.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),e===!0){let s=this.children;for(let r=0,a=s.length;r<a;r++)s[r].updateWorldMatrix(!1,!0)}}toJSON(t){let e=t===void 0||typeof t=="string",i={};e&&(t={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},i.metadata={version:4.6,type:"Object",generator:"Object3D.toJSON"});let s={};s.uuid=this.uuid,s.type=this.type,this.name!==""&&(s.name=this.name),this.castShadow===!0&&(s.castShadow=!0),this.receiveShadow===!0&&(s.receiveShadow=!0),this.visible===!1&&(s.visible=!1),this.frustumCulled===!1&&(s.frustumCulled=!1),this.renderOrder!==0&&(s.renderOrder=this.renderOrder),Object.keys(this.userData).length>0&&(s.userData=this.userData),s.layers=this.layers.mask,s.matrix=this.matrix.toArray(),s.up=this.up.toArray(),this.matrixAutoUpdate===!1&&(s.matrixAutoUpdate=!1),this.isInstancedMesh&&(s.type="InstancedMesh",s.count=this.count,s.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(s.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(s.type="BatchedMesh",s.perObjectFrustumCulled=this.perObjectFrustumCulled,s.sortObjects=this.sortObjects,s.drawRanges=this._drawRanges,s.reservedRanges=this._reservedRanges,s.visibility=this._visibility,s.active=this._active,s.bounds=this._bounds.map(o=>({boxInitialized:o.boxInitialized,boxMin:o.box.min.toArray(),boxMax:o.box.max.toArray(),sphereInitialized:o.sphereInitialized,sphereRadius:o.sphere.radius,sphereCenter:o.sphere.center.toArray()})),s.maxInstanceCount=this._maxInstanceCount,s.maxVertexCount=this._maxVertexCount,s.maxIndexCount=this._maxIndexCount,s.geometryInitialized=this._geometryInitialized,s.geometryCount=this._geometryCount,s.matricesTexture=this._matricesTexture.toJSON(t),this._colorsTexture!==null&&(s.colorsTexture=this._colorsTexture.toJSON(t)),this.boundingSphere!==null&&(s.boundingSphere={center:s.boundingSphere.center.toArray(),radius:s.boundingSphere.radius}),this.boundingBox!==null&&(s.boundingBox={min:s.boundingBox.min.toArray(),max:s.boundingBox.max.toArray()}));function r(o,l){return o[l.uuid]===void 0&&(o[l.uuid]=l.toJSON(t)),l.uuid}if(this.isScene)this.background&&(this.background.isColor?s.background=this.background.toJSON():this.background.isTexture&&(s.background=this.background.toJSON(t).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(s.environment=this.environment.toJSON(t).uuid);else if(this.isMesh||this.isLine||this.isPoints){s.geometry=r(t.geometries,this.geometry);let o=this.geometry.parameters;if(o!==void 0&&o.shapes!==void 0){let l=o.shapes;if(Array.isArray(l))for(let c=0,h=l.length;c<h;c++){let d=l[c];r(t.shapes,d)}else r(t.shapes,l)}}if(this.isSkinnedMesh&&(s.bindMode=this.bindMode,s.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(r(t.skeletons,this.skeleton),s.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){let o=[];for(let l=0,c=this.material.length;l<c;l++)o.push(r(t.materials,this.material[l]));s.material=o}else s.material=r(t.materials,this.material);if(this.children.length>0){s.children=[];for(let o=0;o<this.children.length;o++)s.children.push(this.children[o].toJSON(t).object)}if(this.animations.length>0){s.animations=[];for(let o=0;o<this.animations.length;o++){let l=this.animations[o];s.animations.push(r(t.animations,l))}}if(e){let o=a(t.geometries),l=a(t.materials),c=a(t.textures),h=a(t.images),d=a(t.shapes),u=a(t.skeletons),f=a(t.animations),x=a(t.nodes);o.length>0&&(i.geometries=o),l.length>0&&(i.materials=l),c.length>0&&(i.textures=c),h.length>0&&(i.images=h),d.length>0&&(i.shapes=d),u.length>0&&(i.skeletons=u),f.length>0&&(i.animations=f),x.length>0&&(i.nodes=x)}return i.object=s,i;function a(o){let l=[];for(let c in o){let h=o[c];delete h.metadata,l.push(h)}return l}}clone(t){return new this.constructor().copy(this,t)}copy(t,e=!0){if(this.name=t.name,this.up.copy(t.up),this.position.copy(t.position),this.rotation.order=t.rotation.order,this.quaternion.copy(t.quaternion),this.scale.copy(t.scale),this.matrix.copy(t.matrix),this.matrixWorld.copy(t.matrixWorld),this.matrixAutoUpdate=t.matrixAutoUpdate,this.matrixWorldAutoUpdate=t.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=t.matrixWorldNeedsUpdate,this.layers.mask=t.layers.mask,this.visible=t.visible,this.castShadow=t.castShadow,this.receiveShadow=t.receiveShadow,this.frustumCulled=t.frustumCulled,this.renderOrder=t.renderOrder,this.animations=t.animations.slice(),this.userData=JSON.parse(JSON.stringify(t.userData)),e===!0)for(let i=0;i<t.children.length;i++){let s=t.children[i];this.add(s.clone())}return this}};Oe.DEFAULT_UP=new O(0,1,0);Oe.DEFAULT_MATRIX_AUTO_UPDATE=!0;Oe.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;var Wn=new O,_i=new O,bc=new O,vi=new O,nr=new O,ir=new O,Fu=new O,Ac=new O,Rc=new O,Cc=new O,Pc=new Le,Ic=new Le,Lc=new Le,Zi=class n{constructor(t=new O,e=new O,i=new O){this.a=t,this.b=e,this.c=i}static getNormal(t,e,i,s){s.subVectors(i,e),Wn.subVectors(t,e),s.cross(Wn);let r=s.lengthSq();return r>0?s.multiplyScalar(1/Math.sqrt(r)):s.set(0,0,0)}static getBarycoord(t,e,i,s,r){Wn.subVectors(s,e),_i.subVectors(i,e),bc.subVectors(t,e);let a=Wn.dot(Wn),o=Wn.dot(_i),l=Wn.dot(bc),c=_i.dot(_i),h=_i.dot(bc),d=a*c-o*o;if(d===0)return r.set(0,0,0),null;let u=1/d,f=(c*l-o*h)*u,x=(a*h-o*l)*u;return r.set(1-f-x,x,f)}static containsPoint(t,e,i,s){return this.getBarycoord(t,e,i,s,vi)===null?!1:vi.x>=0&&vi.y>=0&&vi.x+vi.y<=1}static getInterpolation(t,e,i,s,r,a,o,l){return this.getBarycoord(t,e,i,s,vi)===null?(l.x=0,l.y=0,"z"in l&&(l.z=0),"w"in l&&(l.w=0),null):(l.setScalar(0),l.addScaledVector(r,vi.x),l.addScaledVector(a,vi.y),l.addScaledVector(o,vi.z),l)}static getInterpolatedAttribute(t,e,i,s,r,a){return Pc.setScalar(0),Ic.setScalar(0),Lc.setScalar(0),Pc.fromBufferAttribute(t,e),Ic.fromBufferAttribute(t,i),Lc.fromBufferAttribute(t,s),a.setScalar(0),a.addScaledVector(Pc,r.x),a.addScaledVector(Ic,r.y),a.addScaledVector(Lc,r.z),a}static isFrontFacing(t,e,i,s){return Wn.subVectors(i,e),_i.subVectors(t,e),Wn.cross(_i).dot(s)<0}set(t,e,i){return this.a.copy(t),this.b.copy(e),this.c.copy(i),this}setFromPointsAndIndices(t,e,i,s){return this.a.copy(t[e]),this.b.copy(t[i]),this.c.copy(t[s]),this}setFromAttributeAndIndices(t,e,i,s){return this.a.fromBufferAttribute(t,e),this.b.fromBufferAttribute(t,i),this.c.fromBufferAttribute(t,s),this}clone(){return new this.constructor().copy(this)}copy(t){return this.a.copy(t.a),this.b.copy(t.b),this.c.copy(t.c),this}getArea(){return Wn.subVectors(this.c,this.b),_i.subVectors(this.a,this.b),Wn.cross(_i).length()*.5}getMidpoint(t){return t.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(t){return n.getNormal(this.a,this.b,this.c,t)}getPlane(t){return t.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(t,e){return n.getBarycoord(t,this.a,this.b,this.c,e)}getInterpolation(t,e,i,s,r){return n.getInterpolation(t,this.a,this.b,this.c,e,i,s,r)}containsPoint(t){return n.containsPoint(t,this.a,this.b,this.c)}isFrontFacing(t){return n.isFrontFacing(this.a,this.b,this.c,t)}intersectsBox(t){return t.intersectsTriangle(this)}closestPointToPoint(t,e){let i=this.a,s=this.b,r=this.c,a,o;nr.subVectors(s,i),ir.subVectors(r,i),Ac.subVectors(t,i);let l=nr.dot(Ac),c=ir.dot(Ac);if(l<=0&&c<=0)return e.copy(i);Rc.subVectors(t,s);let h=nr.dot(Rc),d=ir.dot(Rc);if(h>=0&&d<=h)return e.copy(s);let u=l*d-h*c;if(u<=0&&l>=0&&h<=0)return a=l/(l-h),e.copy(i).addScaledVector(nr,a);Cc.subVectors(t,r);let f=nr.dot(Cc),x=ir.dot(Cc);if(x>=0&&f<=x)return e.copy(r);let M=f*c-l*x;if(M<=0&&c>=0&&x<=0)return o=c/(c-x),e.copy(i).addScaledVector(ir,o);let m=h*x-f*d;if(m<=0&&d-h>=0&&f-x>=0)return Fu.subVectors(r,s),o=(d-h)/(d-h+(f-x)),e.copy(s).addScaledVector(Fu,o);let p=1/(m+M+u);return a=M*p,o=u*p,e.copy(i).addScaledVector(nr,a).addScaledVector(ir,o)}equals(t){return t.a.equals(this.a)&&t.b.equals(this.b)&&t.c.equals(this.c)}},Bd={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},Yi={h:0,s:0,l:0},aa={h:0,s:0,l:0};function Dc(n,t,e){return e<0&&(e+=1),e>1&&(e-=1),e<1/6?n+(t-n)*6*e:e<1/2?t:e<2/3?n+(t-n)*6*(2/3-e):n}var Ot=class{constructor(t,e,i){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(t,e,i)}set(t,e,i){if(e===void 0&&i===void 0){let s=t;s&&s.isColor?this.copy(s):typeof s=="number"?this.setHex(s):typeof s=="string"&&this.setStyle(s)}else this.setRGB(t,e,i);return this}setScalar(t){return this.r=t,this.g=t,this.b=t,this}setHex(t,e=Pe){return t=Math.floor(t),this.r=(t>>16&255)/255,this.g=(t>>8&255)/255,this.b=(t&255)/255,pe.toWorkingColorSpace(this,e),this}setRGB(t,e,i,s=pe.workingColorSpace){return this.r=t,this.g=e,this.b=i,pe.toWorkingColorSpace(this,s),this}setHSL(t,e,i,s=pe.workingColorSpace){if(t=Sp(t,1),e=ie(e,0,1),i=ie(i,0,1),e===0)this.r=this.g=this.b=i;else{let r=i<=.5?i*(1+e):i+e-i*e,a=2*i-r;this.r=Dc(a,r,t+1/3),this.g=Dc(a,r,t),this.b=Dc(a,r,t-1/3)}return pe.toWorkingColorSpace(this,s),this}setStyle(t,e=Pe){function i(r){r!==void 0&&parseFloat(r)<1&&console.warn("THREE.Color: Alpha component of "+t+" will be ignored.")}let s;if(s=/^(\w+)\(([^\)]*)\)/.exec(t)){let r,a=s[1],o=s[2];switch(a){case"rgb":case"rgba":if(r=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return i(r[4]),this.setRGB(Math.min(255,parseInt(r[1],10))/255,Math.min(255,parseInt(r[2],10))/255,Math.min(255,parseInt(r[3],10))/255,e);if(r=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return i(r[4]),this.setRGB(Math.min(100,parseInt(r[1],10))/100,Math.min(100,parseInt(r[2],10))/100,Math.min(100,parseInt(r[3],10))/100,e);break;case"hsl":case"hsla":if(r=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return i(r[4]),this.setHSL(parseFloat(r[1])/360,parseFloat(r[2])/100,parseFloat(r[3])/100,e);break;default:console.warn("THREE.Color: Unknown color model "+t)}}else if(s=/^\#([A-Fa-f\d]+)$/.exec(t)){let r=s[1],a=r.length;if(a===3)return this.setRGB(parseInt(r.charAt(0),16)/15,parseInt(r.charAt(1),16)/15,parseInt(r.charAt(2),16)/15,e);if(a===6)return this.setHex(parseInt(r,16),e);console.warn("THREE.Color: Invalid hex color "+t)}else if(t&&t.length>0)return this.setColorName(t,e);return this}setColorName(t,e=Pe){let i=Bd[t.toLowerCase()];return i!==void 0?this.setHex(i,e):console.warn("THREE.Color: Unknown color "+t),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(t){return this.r=t.r,this.g=t.g,this.b=t.b,this}copySRGBToLinear(t){return this.r=Mi(t.r),this.g=Mi(t.g),this.b=Mi(t.b),this}copyLinearToSRGB(t){return this.r=cr(t.r),this.g=cr(t.g),this.b=cr(t.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(t=Pe){return pe.fromWorkingColorSpace(rn.copy(this),t),Math.round(ie(rn.r*255,0,255))*65536+Math.round(ie(rn.g*255,0,255))*256+Math.round(ie(rn.b*255,0,255))}getHexString(t=Pe){return("000000"+this.getHex(t).toString(16)).slice(-6)}getHSL(t,e=pe.workingColorSpace){pe.fromWorkingColorSpace(rn.copy(this),e);let i=rn.r,s=rn.g,r=rn.b,a=Math.max(i,s,r),o=Math.min(i,s,r),l,c,h=(o+a)/2;if(o===a)l=0,c=0;else{let d=a-o;switch(c=h<=.5?d/(a+o):d/(2-a-o),a){case i:l=(s-r)/d+(s<r?6:0);break;case s:l=(r-i)/d+2;break;case r:l=(i-s)/d+4;break}l/=6}return t.h=l,t.s=c,t.l=h,t}getRGB(t,e=pe.workingColorSpace){return pe.fromWorkingColorSpace(rn.copy(this),e),t.r=rn.r,t.g=rn.g,t.b=rn.b,t}getStyle(t=Pe){pe.fromWorkingColorSpace(rn.copy(this),t);let e=rn.r,i=rn.g,s=rn.b;return t!==Pe?`color(${t} ${e.toFixed(3)} ${i.toFixed(3)} ${s.toFixed(3)})`:`rgb(${Math.round(e*255)},${Math.round(i*255)},${Math.round(s*255)})`}offsetHSL(t,e,i){return this.getHSL(Yi),this.setHSL(Yi.h+t,Yi.s+e,Yi.l+i)}add(t){return this.r+=t.r,this.g+=t.g,this.b+=t.b,this}addColors(t,e){return this.r=t.r+e.r,this.g=t.g+e.g,this.b=t.b+e.b,this}addScalar(t){return this.r+=t,this.g+=t,this.b+=t,this}sub(t){return this.r=Math.max(0,this.r-t.r),this.g=Math.max(0,this.g-t.g),this.b=Math.max(0,this.b-t.b),this}multiply(t){return this.r*=t.r,this.g*=t.g,this.b*=t.b,this}multiplyScalar(t){return this.r*=t,this.g*=t,this.b*=t,this}lerp(t,e){return this.r+=(t.r-this.r)*e,this.g+=(t.g-this.g)*e,this.b+=(t.b-this.b)*e,this}lerpColors(t,e,i){return this.r=t.r+(e.r-t.r)*i,this.g=t.g+(e.g-t.g)*i,this.b=t.b+(e.b-t.b)*i,this}lerpHSL(t,e){this.getHSL(Yi),t.getHSL(aa);let i=gc(Yi.h,aa.h,e),s=gc(Yi.s,aa.s,e),r=gc(Yi.l,aa.l,e);return this.setHSL(i,s,r),this}setFromVector3(t){return this.r=t.x,this.g=t.y,this.b=t.z,this}applyMatrix3(t){let e=this.r,i=this.g,s=this.b,r=t.elements;return this.r=r[0]*e+r[3]*i+r[6]*s,this.g=r[1]*e+r[4]*i+r[7]*s,this.b=r[2]*e+r[5]*i+r[8]*s,this}equals(t){return t.r===this.r&&t.g===this.g&&t.b===this.b}fromArray(t,e=0){return this.r=t[e],this.g=t[e+1],this.b=t[e+2],this}toArray(t=[],e=0){return t[e]=this.r,t[e+1]=this.g,t[e+2]=this.b,t}fromBufferAttribute(t,e){return this.r=t.getX(e),this.g=t.getY(e),this.b=t.getZ(e),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}},rn=new Ot;Ot.NAMES=Bd;var Up=0,bi=class extends wi{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:Up++}),this.uuid=Mr(),this.name="",this.type="Material",this.blending=ws,this.side=Si,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=Sa,this.blendDst=wa,this.blendEquation=Ki,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new Ot(0,0,0),this.blendAlpha=0,this.depthFunc=Ts,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=Wc,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=Es,this.stencilZFail=Es,this.stencilZPass=Es,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(t){this._alphaTest>0!=t>0&&this.version++,this._alphaTest=t}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(t){if(t!==void 0)for(let e in t){let i=t[e];if(i===void 0){console.warn(`THREE.Material: parameter '${e}' has value of undefined.`);continue}let s=this[e];if(s===void 0){console.warn(`THREE.Material: '${e}' is not a property of THREE.${this.type}.`);continue}s&&s.isColor?s.set(i):s&&s.isVector3&&i&&i.isVector3?s.copy(i):this[e]=i}}toJSON(t){let e=t===void 0||typeof t=="string";e&&(t={textures:{},images:{}});let i={metadata:{version:4.6,type:"Material",generator:"Material.toJSON"}};i.uuid=this.uuid,i.type=this.type,this.name!==""&&(i.name=this.name),this.color&&this.color.isColor&&(i.color=this.color.getHex()),this.roughness!==void 0&&(i.roughness=this.roughness),this.metalness!==void 0&&(i.metalness=this.metalness),this.sheen!==void 0&&(i.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(i.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(i.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(i.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&this.emissiveIntensity!==1&&(i.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(i.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(i.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(i.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(i.shininess=this.shininess),this.clearcoat!==void 0&&(i.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(i.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(i.clearcoatMap=this.clearcoatMap.toJSON(t).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(i.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(t).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(i.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(t).uuid,i.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.dispersion!==void 0&&(i.dispersion=this.dispersion),this.iridescence!==void 0&&(i.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(i.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(i.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(i.iridescenceMap=this.iridescenceMap.toJSON(t).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(i.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(t).uuid),this.anisotropy!==void 0&&(i.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(i.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(i.anisotropyMap=this.anisotropyMap.toJSON(t).uuid),this.map&&this.map.isTexture&&(i.map=this.map.toJSON(t).uuid),this.matcap&&this.matcap.isTexture&&(i.matcap=this.matcap.toJSON(t).uuid),this.alphaMap&&this.alphaMap.isTexture&&(i.alphaMap=this.alphaMap.toJSON(t).uuid),this.lightMap&&this.lightMap.isTexture&&(i.lightMap=this.lightMap.toJSON(t).uuid,i.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(i.aoMap=this.aoMap.toJSON(t).uuid,i.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(i.bumpMap=this.bumpMap.toJSON(t).uuid,i.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(i.normalMap=this.normalMap.toJSON(t).uuid,i.normalMapType=this.normalMapType,i.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(i.displacementMap=this.displacementMap.toJSON(t).uuid,i.displacementScale=this.displacementScale,i.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(i.roughnessMap=this.roughnessMap.toJSON(t).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(i.metalnessMap=this.metalnessMap.toJSON(t).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(i.emissiveMap=this.emissiveMap.toJSON(t).uuid),this.specularMap&&this.specularMap.isTexture&&(i.specularMap=this.specularMap.toJSON(t).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(i.specularIntensityMap=this.specularIntensityMap.toJSON(t).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(i.specularColorMap=this.specularColorMap.toJSON(t).uuid),this.envMap&&this.envMap.isTexture&&(i.envMap=this.envMap.toJSON(t).uuid,this.combine!==void 0&&(i.combine=this.combine)),this.envMapRotation!==void 0&&(i.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(i.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(i.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(i.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(i.gradientMap=this.gradientMap.toJSON(t).uuid),this.transmission!==void 0&&(i.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(i.transmissionMap=this.transmissionMap.toJSON(t).uuid),this.thickness!==void 0&&(i.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(i.thicknessMap=this.thicknessMap.toJSON(t).uuid),this.attenuationDistance!==void 0&&this.attenuationDistance!==1/0&&(i.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(i.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(i.size=this.size),this.shadowSide!==null&&(i.shadowSide=this.shadowSide),this.sizeAttenuation!==void 0&&(i.sizeAttenuation=this.sizeAttenuation),this.blending!==ws&&(i.blending=this.blending),this.side!==Si&&(i.side=this.side),this.vertexColors===!0&&(i.vertexColors=!0),this.opacity<1&&(i.opacity=this.opacity),this.transparent===!0&&(i.transparent=!0),this.blendSrc!==Sa&&(i.blendSrc=this.blendSrc),this.blendDst!==wa&&(i.blendDst=this.blendDst),this.blendEquation!==Ki&&(i.blendEquation=this.blendEquation),this.blendSrcAlpha!==null&&(i.blendSrcAlpha=this.blendSrcAlpha),this.blendDstAlpha!==null&&(i.blendDstAlpha=this.blendDstAlpha),this.blendEquationAlpha!==null&&(i.blendEquationAlpha=this.blendEquationAlpha),this.blendColor&&this.blendColor.isColor&&(i.blendColor=this.blendColor.getHex()),this.blendAlpha!==0&&(i.blendAlpha=this.blendAlpha),this.depthFunc!==Ts&&(i.depthFunc=this.depthFunc),this.depthTest===!1&&(i.depthTest=this.depthTest),this.depthWrite===!1&&(i.depthWrite=this.depthWrite),this.colorWrite===!1&&(i.colorWrite=this.colorWrite),this.stencilWriteMask!==255&&(i.stencilWriteMask=this.stencilWriteMask),this.stencilFunc!==Wc&&(i.stencilFunc=this.stencilFunc),this.stencilRef!==0&&(i.stencilRef=this.stencilRef),this.stencilFuncMask!==255&&(i.stencilFuncMask=this.stencilFuncMask),this.stencilFail!==Es&&(i.stencilFail=this.stencilFail),this.stencilZFail!==Es&&(i.stencilZFail=this.stencilZFail),this.stencilZPass!==Es&&(i.stencilZPass=this.stencilZPass),this.stencilWrite===!0&&(i.stencilWrite=this.stencilWrite),this.rotation!==void 0&&this.rotation!==0&&(i.rotation=this.rotation),this.polygonOffset===!0&&(i.polygonOffset=!0),this.polygonOffsetFactor!==0&&(i.polygonOffsetFactor=this.polygonOffsetFactor),this.polygonOffsetUnits!==0&&(i.polygonOffsetUnits=this.polygonOffsetUnits),this.linewidth!==void 0&&this.linewidth!==1&&(i.linewidth=this.linewidth),this.dashSize!==void 0&&(i.dashSize=this.dashSize),this.gapSize!==void 0&&(i.gapSize=this.gapSize),this.scale!==void 0&&(i.scale=this.scale),this.dithering===!0&&(i.dithering=!0),this.alphaTest>0&&(i.alphaTest=this.alphaTest),this.alphaHash===!0&&(i.alphaHash=!0),this.alphaToCoverage===!0&&(i.alphaToCoverage=!0),this.premultipliedAlpha===!0&&(i.premultipliedAlpha=!0),this.forceSinglePass===!0&&(i.forceSinglePass=!0),this.wireframe===!0&&(i.wireframe=!0),this.wireframeLinewidth>1&&(i.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!=="round"&&(i.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!=="round"&&(i.wireframeLinejoin=this.wireframeLinejoin),this.flatShading===!0&&(i.flatShading=!0),this.visible===!1&&(i.visible=!1),this.toneMapped===!1&&(i.toneMapped=!1),this.fog===!1&&(i.fog=!1),Object.keys(this.userData).length>0&&(i.userData=this.userData);function s(r){let a=[];for(let o in r){let l=r[o];delete l.metadata,a.push(l)}return a}if(e){let r=s(t.textures),a=s(t.images);r.length>0&&(i.textures=r),a.length>0&&(i.images=a)}return i}clone(){return new this.constructor().copy(this)}copy(t){this.name=t.name,this.blending=t.blending,this.side=t.side,this.vertexColors=t.vertexColors,this.opacity=t.opacity,this.transparent=t.transparent,this.blendSrc=t.blendSrc,this.blendDst=t.blendDst,this.blendEquation=t.blendEquation,this.blendSrcAlpha=t.blendSrcAlpha,this.blendDstAlpha=t.blendDstAlpha,this.blendEquationAlpha=t.blendEquationAlpha,this.blendColor.copy(t.blendColor),this.blendAlpha=t.blendAlpha,this.depthFunc=t.depthFunc,this.depthTest=t.depthTest,this.depthWrite=t.depthWrite,this.stencilWriteMask=t.stencilWriteMask,this.stencilFunc=t.stencilFunc,this.stencilRef=t.stencilRef,this.stencilFuncMask=t.stencilFuncMask,this.stencilFail=t.stencilFail,this.stencilZFail=t.stencilZFail,this.stencilZPass=t.stencilZPass,this.stencilWrite=t.stencilWrite;let e=t.clippingPlanes,i=null;if(e!==null){let s=e.length;i=new Array(s);for(let r=0;r!==s;++r)i[r]=e[r].clone()}return this.clippingPlanes=i,this.clipIntersection=t.clipIntersection,this.clipShadows=t.clipShadows,this.shadowSide=t.shadowSide,this.colorWrite=t.colorWrite,this.precision=t.precision,this.polygonOffset=t.polygonOffset,this.polygonOffsetFactor=t.polygonOffsetFactor,this.polygonOffsetUnits=t.polygonOffsetUnits,this.dithering=t.dithering,this.alphaTest=t.alphaTest,this.alphaHash=t.alphaHash,this.alphaToCoverage=t.alphaToCoverage,this.premultipliedAlpha=t.premultipliedAlpha,this.forceSinglePass=t.forceSinglePass,this.visible=t.visible,this.toneMapped=t.toneMapped,this.userData=JSON.parse(JSON.stringify(t.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(t){t===!0&&this.version++}onBuild(){console.warn("Material: onBuild() has been removed.")}},Se=class extends bi{constructor(t){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new Ot(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Ln,this.combine=rl,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.specularMap=t.specularMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.combine=t.combine,this.reflectivity=t.reflectivity,this.refractionRatio=t.refractionRatio,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.fog=t.fog,this}};var ke=new O,la=new at,gn=class{constructor(t,e,i=!1){if(Array.isArray(t))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,this.name="",this.array=t,this.itemSize=e,this.count=t!==void 0?t.length/e:0,this.normalized=i,this.usage=Xc,this.updateRanges=[],this.gpuType=Yn,this.version=0}onUploadCallback(){}set needsUpdate(t){t===!0&&this.version++}setUsage(t){return this.usage=t,this}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}copy(t){return this.name=t.name,this.array=new t.array.constructor(t.array),this.itemSize=t.itemSize,this.count=t.count,this.normalized=t.normalized,this.usage=t.usage,this.gpuType=t.gpuType,this}copyAt(t,e,i){t*=this.itemSize,i*=e.itemSize;for(let s=0,r=this.itemSize;s<r;s++)this.array[t+s]=e.array[i+s];return this}copyArray(t){return this.array.set(t),this}applyMatrix3(t){if(this.itemSize===2)for(let e=0,i=this.count;e<i;e++)la.fromBufferAttribute(this,e),la.applyMatrix3(t),this.setXY(e,la.x,la.y);else if(this.itemSize===3)for(let e=0,i=this.count;e<i;e++)ke.fromBufferAttribute(this,e),ke.applyMatrix3(t),this.setXYZ(e,ke.x,ke.y,ke.z);return this}applyMatrix4(t){for(let e=0,i=this.count;e<i;e++)ke.fromBufferAttribute(this,e),ke.applyMatrix4(t),this.setXYZ(e,ke.x,ke.y,ke.z);return this}applyNormalMatrix(t){for(let e=0,i=this.count;e<i;e++)ke.fromBufferAttribute(this,e),ke.applyNormalMatrix(t),this.setXYZ(e,ke.x,ke.y,ke.z);return this}transformDirection(t){for(let e=0,i=this.count;e<i;e++)ke.fromBufferAttribute(this,e),ke.transformDirection(t),this.setXYZ(e,ke.x,ke.y,ke.z);return this}set(t,e=0){return this.array.set(t,e),this}getComponent(t,e){let i=this.array[t*this.itemSize+e];return this.normalized&&(i=Or(i,this.array)),i}setComponent(t,e,i){return this.normalized&&(i=mn(i,this.array)),this.array[t*this.itemSize+e]=i,this}getX(t){let e=this.array[t*this.itemSize];return this.normalized&&(e=Or(e,this.array)),e}setX(t,e){return this.normalized&&(e=mn(e,this.array)),this.array[t*this.itemSize]=e,this}getY(t){let e=this.array[t*this.itemSize+1];return this.normalized&&(e=Or(e,this.array)),e}setY(t,e){return this.normalized&&(e=mn(e,this.array)),this.array[t*this.itemSize+1]=e,this}getZ(t){let e=this.array[t*this.itemSize+2];return this.normalized&&(e=Or(e,this.array)),e}setZ(t,e){return this.normalized&&(e=mn(e,this.array)),this.array[t*this.itemSize+2]=e,this}getW(t){let e=this.array[t*this.itemSize+3];return this.normalized&&(e=Or(e,this.array)),e}setW(t,e){return this.normalized&&(e=mn(e,this.array)),this.array[t*this.itemSize+3]=e,this}setXY(t,e,i){return t*=this.itemSize,this.normalized&&(e=mn(e,this.array),i=mn(i,this.array)),this.array[t+0]=e,this.array[t+1]=i,this}setXYZ(t,e,i,s){return t*=this.itemSize,this.normalized&&(e=mn(e,this.array),i=mn(i,this.array),s=mn(s,this.array)),this.array[t+0]=e,this.array[t+1]=i,this.array[t+2]=s,this}setXYZW(t,e,i,s,r){return t*=this.itemSize,this.normalized&&(e=mn(e,this.array),i=mn(i,this.array),s=mn(s,this.array),r=mn(r,this.array)),this.array[t+0]=e,this.array[t+1]=i,this.array[t+2]=s,this.array[t+3]=r,this}onUpload(t){return this.onUploadCallback=t,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){let t={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return this.name!==""&&(t.name=this.name),this.usage!==Xc&&(t.usage=this.usage),t}};var Qr=class extends gn{constructor(t,e,i){super(new Uint16Array(t),e,i)}};var jr=class extends gn{constructor(t,e,i){super(new Uint32Array(t),e,i)}};var se=class extends gn{constructor(t,e,i){super(new Float32Array(t),e,i)}},Np=0,In=new be,Uc=new Oe,sr=new O,Tn=new ii,zr=new ii,Xe=new O,qe=class n extends wi{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:Np++}),this.uuid=Mr(),this.name="",this.type="BufferGeometry",this.index=null,this.indirect=null,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={}}getIndex(){return this.index}setIndex(t){return Array.isArray(t)?this.index=new(ph(t)?jr:Qr)(t,1):this.index=t,this}setIndirect(t){return this.indirect=t,this}getIndirect(){return this.indirect}getAttribute(t){return this.attributes[t]}setAttribute(t,e){return this.attributes[t]=e,this}deleteAttribute(t){return delete this.attributes[t],this}hasAttribute(t){return this.attributes[t]!==void 0}addGroup(t,e,i=0){this.groups.push({start:t,count:e,materialIndex:i})}clearGroups(){this.groups=[]}setDrawRange(t,e){this.drawRange.start=t,this.drawRange.count=e}applyMatrix4(t){let e=this.attributes.position;e!==void 0&&(e.applyMatrix4(t),e.needsUpdate=!0);let i=this.attributes.normal;if(i!==void 0){let r=new Qt().getNormalMatrix(t);i.applyNormalMatrix(r),i.needsUpdate=!0}let s=this.attributes.tangent;return s!==void 0&&(s.transformDirection(t),s.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this}applyQuaternion(t){return In.makeRotationFromQuaternion(t),this.applyMatrix4(In),this}rotateX(t){return In.makeRotationX(t),this.applyMatrix4(In),this}rotateY(t){return In.makeRotationY(t),this.applyMatrix4(In),this}rotateZ(t){return In.makeRotationZ(t),this.applyMatrix4(In),this}translate(t,e,i){return In.makeTranslation(t,e,i),this.applyMatrix4(In),this}scale(t,e,i){return In.makeScale(t,e,i),this.applyMatrix4(In),this}lookAt(t){return Uc.lookAt(t),Uc.updateMatrix(),this.applyMatrix4(Uc.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter(sr).negate(),this.translate(sr.x,sr.y,sr.z),this}setFromPoints(t){let e=this.getAttribute("position");if(e===void 0){let i=[];for(let s=0,r=t.length;s<r;s++){let a=t[s];i.push(a.x,a.y,a.z||0)}this.setAttribute("position",new se(i,3))}else{let i=Math.min(t.length,e.count);for(let s=0;s<i;s++){let r=t[s];e.setXYZ(s,r.x,r.y,r.z||0)}t.length>e.count&&console.warn("THREE.BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry."),e.needsUpdate=!0}return this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new ii);let t=this.attributes.position,e=this.morphAttributes.position;if(t&&t.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new O(-1/0,-1/0,-1/0),new O(1/0,1/0,1/0));return}if(t!==void 0){if(this.boundingBox.setFromBufferAttribute(t),e)for(let i=0,s=e.length;i<s;i++){let r=e[i];Tn.setFromBufferAttribute(r),this.morphTargetsRelative?(Xe.addVectors(this.boundingBox.min,Tn.min),this.boundingBox.expandByPoint(Xe),Xe.addVectors(this.boundingBox.max,Tn.max),this.boundingBox.expandByPoint(Xe)):(this.boundingBox.expandByPoint(Tn.min),this.boundingBox.expandByPoint(Tn.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&console.error('THREE.BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new Qi);let t=this.attributes.position,e=this.morphAttributes.position;if(t&&t.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new O,1/0);return}if(t){let i=this.boundingSphere.center;if(Tn.setFromBufferAttribute(t),e)for(let r=0,a=e.length;r<a;r++){let o=e[r];zr.setFromBufferAttribute(o),this.morphTargetsRelative?(Xe.addVectors(Tn.min,zr.min),Tn.expandByPoint(Xe),Xe.addVectors(Tn.max,zr.max),Tn.expandByPoint(Xe)):(Tn.expandByPoint(zr.min),Tn.expandByPoint(zr.max))}Tn.getCenter(i);let s=0;for(let r=0,a=t.count;r<a;r++)Xe.fromBufferAttribute(t,r),s=Math.max(s,i.distanceToSquared(Xe));if(e)for(let r=0,a=e.length;r<a;r++){let o=e[r],l=this.morphTargetsRelative;for(let c=0,h=o.count;c<h;c++)Xe.fromBufferAttribute(o,c),l&&(sr.fromBufferAttribute(t,c),Xe.add(sr)),s=Math.max(s,i.distanceToSquared(Xe))}this.boundingSphere.radius=Math.sqrt(s),isNaN(this.boundingSphere.radius)&&console.error('THREE.BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){let t=this.index,e=this.attributes;if(t===null||e.position===void 0||e.normal===void 0||e.uv===void 0){console.error("THREE.BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}let i=e.position,s=e.normal,r=e.uv;this.hasAttribute("tangent")===!1&&this.setAttribute("tangent",new gn(new Float32Array(4*i.count),4));let a=this.getAttribute("tangent"),o=[],l=[];for(let T=0;T<i.count;T++)o[T]=new O,l[T]=new O;let c=new O,h=new O,d=new O,u=new at,f=new at,x=new at,M=new O,m=new O;function p(T,v,y){c.fromBufferAttribute(i,T),h.fromBufferAttribute(i,v),d.fromBufferAttribute(i,y),u.fromBufferAttribute(r,T),f.fromBufferAttribute(r,v),x.fromBufferAttribute(r,y),h.sub(c),d.sub(c),f.sub(u),x.sub(u);let w=1/(f.x*x.y-x.x*f.y);isFinite(w)&&(M.copy(h).multiplyScalar(x.y).addScaledVector(d,-f.y).multiplyScalar(w),m.copy(d).multiplyScalar(f.x).addScaledVector(h,-x.x).multiplyScalar(w),o[T].add(M),o[v].add(M),o[y].add(M),l[T].add(m),l[v].add(m),l[y].add(m))}let S=this.groups;S.length===0&&(S=[{start:0,count:t.count}]);for(let T=0,v=S.length;T<v;++T){let y=S[T],w=y.start,P=y.count;for(let D=w,N=w+P;D<N;D+=3)p(t.getX(D+0),t.getX(D+1),t.getX(D+2))}let E=new O,g=new O,C=new O,A=new O;function _(T){C.fromBufferAttribute(s,T),A.copy(C);let v=o[T];E.copy(v),E.sub(C.multiplyScalar(C.dot(v))).normalize(),g.crossVectors(A,v);let w=g.dot(l[T])<0?-1:1;a.setXYZW(T,E.x,E.y,E.z,w)}for(let T=0,v=S.length;T<v;++T){let y=S[T],w=y.start,P=y.count;for(let D=w,N=w+P;D<N;D+=3)_(t.getX(D+0)),_(t.getX(D+1)),_(t.getX(D+2))}}computeVertexNormals(){let t=this.index,e=this.getAttribute("position");if(e!==void 0){let i=this.getAttribute("normal");if(i===void 0)i=new gn(new Float32Array(e.count*3),3),this.setAttribute("normal",i);else for(let u=0,f=i.count;u<f;u++)i.setXYZ(u,0,0,0);let s=new O,r=new O,a=new O,o=new O,l=new O,c=new O,h=new O,d=new O;if(t)for(let u=0,f=t.count;u<f;u+=3){let x=t.getX(u+0),M=t.getX(u+1),m=t.getX(u+2);s.fromBufferAttribute(e,x),r.fromBufferAttribute(e,M),a.fromBufferAttribute(e,m),h.subVectors(a,r),d.subVectors(s,r),h.cross(d),o.fromBufferAttribute(i,x),l.fromBufferAttribute(i,M),c.fromBufferAttribute(i,m),o.add(h),l.add(h),c.add(h),i.setXYZ(x,o.x,o.y,o.z),i.setXYZ(M,l.x,l.y,l.z),i.setXYZ(m,c.x,c.y,c.z)}else for(let u=0,f=e.count;u<f;u+=3)s.fromBufferAttribute(e,u+0),r.fromBufferAttribute(e,u+1),a.fromBufferAttribute(e,u+2),h.subVectors(a,r),d.subVectors(s,r),h.cross(d),i.setXYZ(u+0,h.x,h.y,h.z),i.setXYZ(u+1,h.x,h.y,h.z),i.setXYZ(u+2,h.x,h.y,h.z);this.normalizeNormals(),i.needsUpdate=!0}}normalizeNormals(){let t=this.attributes.normal;for(let e=0,i=t.count;e<i;e++)Xe.fromBufferAttribute(t,e),Xe.normalize(),t.setXYZ(e,Xe.x,Xe.y,Xe.z)}toNonIndexed(){function t(o,l){let c=o.array,h=o.itemSize,d=o.normalized,u=new c.constructor(l.length*h),f=0,x=0;for(let M=0,m=l.length;M<m;M++){o.isInterleavedBufferAttribute?f=l[M]*o.data.stride+o.offset:f=l[M]*h;for(let p=0;p<h;p++)u[x++]=c[f++]}return new gn(u,h,d)}if(this.index===null)return console.warn("THREE.BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;let e=new n,i=this.index.array,s=this.attributes;for(let o in s){let l=s[o],c=t(l,i);e.setAttribute(o,c)}let r=this.morphAttributes;for(let o in r){let l=[],c=r[o];for(let h=0,d=c.length;h<d;h++){let u=c[h],f=t(u,i);l.push(f)}e.morphAttributes[o]=l}e.morphTargetsRelative=this.morphTargetsRelative;let a=this.groups;for(let o=0,l=a.length;o<l;o++){let c=a[o];e.addGroup(c.start,c.count,c.materialIndex)}return e}toJSON(){let t={metadata:{version:4.6,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(t.uuid=this.uuid,t.type=this.type,this.name!==""&&(t.name=this.name),Object.keys(this.userData).length>0&&(t.userData=this.userData),this.parameters!==void 0){let l=this.parameters;for(let c in l)l[c]!==void 0&&(t[c]=l[c]);return t}t.data={attributes:{}};let e=this.index;e!==null&&(t.data.index={type:e.array.constructor.name,array:Array.prototype.slice.call(e.array)});let i=this.attributes;for(let l in i){let c=i[l];t.data.attributes[l]=c.toJSON(t.data)}let s={},r=!1;for(let l in this.morphAttributes){let c=this.morphAttributes[l],h=[];for(let d=0,u=c.length;d<u;d++){let f=c[d];h.push(f.toJSON(t.data))}h.length>0&&(s[l]=h,r=!0)}r&&(t.data.morphAttributes=s,t.data.morphTargetsRelative=this.morphTargetsRelative);let a=this.groups;a.length>0&&(t.data.groups=JSON.parse(JSON.stringify(a)));let o=this.boundingSphere;return o!==null&&(t.data.boundingSphere={center:o.center.toArray(),radius:o.radius}),t}clone(){return new this.constructor().copy(this)}copy(t){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;let e={};this.name=t.name;let i=t.index;i!==null&&this.setIndex(i.clone(e));let s=t.attributes;for(let c in s){let h=s[c];this.setAttribute(c,h.clone(e))}let r=t.morphAttributes;for(let c in r){let h=[],d=r[c];for(let u=0,f=d.length;u<f;u++)h.push(d[u].clone(e));this.morphAttributes[c]=h}this.morphTargetsRelative=t.morphTargetsRelative;let a=t.groups;for(let c=0,h=a.length;c<h;c++){let d=a[c];this.addGroup(d.start,d.count,d.materialIndex)}let o=t.boundingBox;o!==null&&(this.boundingBox=o.clone());let l=t.boundingSphere;return l!==null&&(this.boundingSphere=l.clone()),this.drawRange.start=t.drawRange.start,this.drawRange.count=t.drawRange.count,this.userData=t.userData,this}dispose(){this.dispatchEvent({type:"dispose"})}},Ou=new be,vs=new Pa,ca=new Qi,Hu=new O,ha=new O,ua=new O,da=new O,Nc=new O,fa=new O,Bu=new O,pa=new O,$=class extends Oe{constructor(t=new qe,e=new Se){super(),this.isMesh=!0,this.type="Mesh",this.geometry=t,this.material=e,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),t.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=t.morphTargetInfluences.slice()),t.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},t.morphTargetDictionary)),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}updateMorphTargets(){let e=this.geometry.morphAttributes,i=Object.keys(e);if(i.length>0){let s=e[i[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}getVertexPosition(t,e){let i=this.geometry,s=i.attributes.position,r=i.morphAttributes.position,a=i.morphTargetsRelative;e.fromBufferAttribute(s,t);let o=this.morphTargetInfluences;if(r&&o){fa.set(0,0,0);for(let l=0,c=r.length;l<c;l++){let h=o[l],d=r[l];h!==0&&(Nc.fromBufferAttribute(d,t),a?fa.addScaledVector(Nc,h):fa.addScaledVector(Nc.sub(e),h))}e.add(fa)}return e}raycast(t,e){let i=this.geometry,s=this.material,r=this.matrixWorld;s!==void 0&&(i.boundingSphere===null&&i.computeBoundingSphere(),ca.copy(i.boundingSphere),ca.applyMatrix4(r),vs.copy(t.ray).recast(t.near),!(ca.containsPoint(vs.origin)===!1&&(vs.intersectSphere(ca,Hu)===null||vs.origin.distanceToSquared(Hu)>(t.far-t.near)**2))&&(Ou.copy(r).invert(),vs.copy(t.ray).applyMatrix4(Ou),!(i.boundingBox!==null&&vs.intersectsBox(i.boundingBox)===!1)&&this._computeIntersections(t,e,vs)))}_computeIntersections(t,e,i){let s,r=this.geometry,a=this.material,o=r.index,l=r.attributes.position,c=r.attributes.uv,h=r.attributes.uv1,d=r.attributes.normal,u=r.groups,f=r.drawRange;if(o!==null)if(Array.isArray(a))for(let x=0,M=u.length;x<M;x++){let m=u[x],p=a[m.materialIndex],S=Math.max(m.start,f.start),E=Math.min(o.count,Math.min(m.start+m.count,f.start+f.count));for(let g=S,C=E;g<C;g+=3){let A=o.getX(g),_=o.getX(g+1),T=o.getX(g+2);s=ma(this,p,t,i,c,h,d,A,_,T),s&&(s.faceIndex=Math.floor(g/3),s.face.materialIndex=m.materialIndex,e.push(s))}}else{let x=Math.max(0,f.start),M=Math.min(o.count,f.start+f.count);for(let m=x,p=M;m<p;m+=3){let S=o.getX(m),E=o.getX(m+1),g=o.getX(m+2);s=ma(this,a,t,i,c,h,d,S,E,g),s&&(s.faceIndex=Math.floor(m/3),e.push(s))}}else if(l!==void 0)if(Array.isArray(a))for(let x=0,M=u.length;x<M;x++){let m=u[x],p=a[m.materialIndex],S=Math.max(m.start,f.start),E=Math.min(l.count,Math.min(m.start+m.count,f.start+f.count));for(let g=S,C=E;g<C;g+=3){let A=g,_=g+1,T=g+2;s=ma(this,p,t,i,c,h,d,A,_,T),s&&(s.faceIndex=Math.floor(g/3),s.face.materialIndex=m.materialIndex,e.push(s))}}else{let x=Math.max(0,f.start),M=Math.min(l.count,f.start+f.count);for(let m=x,p=M;m<p;m+=3){let S=m,E=m+1,g=m+2;s=ma(this,a,t,i,c,h,d,S,E,g),s&&(s.faceIndex=Math.floor(m/3),e.push(s))}}}};function Fp(n,t,e,i,s,r,a,o){let l;if(t.side===je?l=i.intersectTriangle(a,r,s,!0,o):l=i.intersectTriangle(s,r,a,t.side===Si,o),l===null)return null;pa.copy(o),pa.applyMatrix4(n.matrixWorld);let c=e.ray.origin.distanceTo(pa);return c<e.near||c>e.far?null:{distance:c,point:pa.clone(),object:n}}function ma(n,t,e,i,s,r,a,o,l,c){n.getVertexPosition(o,ha),n.getVertexPosition(l,ua),n.getVertexPosition(c,da);let h=Fp(n,t,e,i,ha,ua,da,Bu);if(h){let d=new O;Zi.getBarycoord(Bu,ha,ua,da,d),s&&(h.uv=Zi.getInterpolatedAttribute(s,o,l,c,d,new at)),r&&(h.uv1=Zi.getInterpolatedAttribute(r,o,l,c,d,new at)),a&&(h.normal=Zi.getInterpolatedAttribute(a,o,l,c,d,new O),h.normal.dot(i.direction)>0&&h.normal.multiplyScalar(-1));let u={a:o,b:l,c,normal:new O,materialIndex:0};Zi.getNormal(ha,ua,da,u.normal),h.face=u,h.barycoord=d}return h}var Ee=class n extends qe{constructor(t=1,e=1,i=1,s=1,r=1,a=1){super(),this.type="BoxGeometry",this.parameters={width:t,height:e,depth:i,widthSegments:s,heightSegments:r,depthSegments:a};let o=this;s=Math.floor(s),r=Math.floor(r),a=Math.floor(a);let l=[],c=[],h=[],d=[],u=0,f=0;x("z","y","x",-1,-1,i,e,t,a,r,0),x("z","y","x",1,-1,i,e,-t,a,r,1),x("x","z","y",1,1,t,i,e,s,a,2),x("x","z","y",1,-1,t,i,-e,s,a,3),x("x","y","z",1,-1,t,e,i,s,r,4),x("x","y","z",-1,-1,t,e,-i,s,r,5),this.setIndex(l),this.setAttribute("position",new se(c,3)),this.setAttribute("normal",new se(h,3)),this.setAttribute("uv",new se(d,2));function x(M,m,p,S,E,g,C,A,_,T,v){let y=g/_,w=C/T,P=g/2,D=C/2,N=A/2,H=_+1,U=T+1,k=0,F=0,G=new O;for(let q=0;q<U;q++){let et=q*w-D;for(let nt=0;nt<H;nt++){let rt=nt*y-P;G[M]=rt*S,G[m]=et*E,G[p]=N,c.push(G.x,G.y,G.z),G[M]=0,G[m]=0,G[p]=A>0?1:-1,h.push(G.x,G.y,G.z),d.push(nt/_),d.push(1-q/T),k+=1}}for(let q=0;q<T;q++)for(let et=0;et<_;et++){let nt=u+et+H*q,rt=u+et+H*(q+1),B=u+(et+1)+H*(q+1),Z=u+(et+1)+H*q;l.push(nt,rt,Z),l.push(rt,B,Z),F+=6}o.addGroup(f,F,v),f+=F,u+=k}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.width,t.height,t.depth,t.widthSegments,t.heightSegments,t.depthSegments)}};function Fs(n){let t={};for(let e in n){t[e]={};for(let i in n[e]){let s=n[e][i];s&&(s.isColor||s.isMatrix3||s.isMatrix4||s.isVector2||s.isVector3||s.isVector4||s.isTexture||s.isQuaternion)?s.isRenderTargetTexture?(console.warn("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),t[e][i]=null):t[e][i]=s.clone():Array.isArray(s)?t[e][i]=s.slice():t[e][i]=s}}return t}function cn(n){let t={};for(let e=0;e<n.length;e++){let i=Fs(n[e]);for(let s in i)t[s]=i[s]}return t}function Op(n){let t=[];for(let e=0;e<n.length;e++)t.push(n[e].clone());return t}function mh(n){let t=n.getRenderTarget();return t===null?n.outputColorSpace:t.isXRRenderTarget===!0?t.texture.colorSpace:pe.workingColorSpace}var kd={clone:Fs,merge:cn},Hp=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,Bp=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`,qn=class extends bi{constructor(t){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=Hp,this.fragmentShader=Bp,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,t!==void 0&&this.setValues(t)}copy(t){return super.copy(t),this.fragmentShader=t.fragmentShader,this.vertexShader=t.vertexShader,this.uniforms=Fs(t.uniforms),this.uniformsGroups=Op(t.uniformsGroups),this.defines=Object.assign({},t.defines),this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.fog=t.fog,this.lights=t.lights,this.clipping=t.clipping,this.extensions=Object.assign({},t.extensions),this.glslVersion=t.glslVersion,this}toJSON(t){let e=super.toJSON(t);e.glslVersion=this.glslVersion,e.uniforms={};for(let s in this.uniforms){let a=this.uniforms[s].value;a&&a.isTexture?e.uniforms[s]={type:"t",value:a.toJSON(t).uuid}:a&&a.isColor?e.uniforms[s]={type:"c",value:a.getHex()}:a&&a.isVector2?e.uniforms[s]={type:"v2",value:a.toArray()}:a&&a.isVector3?e.uniforms[s]={type:"v3",value:a.toArray()}:a&&a.isVector4?e.uniforms[s]={type:"v4",value:a.toArray()}:a&&a.isMatrix3?e.uniforms[s]={type:"m3",value:a.toArray()}:a&&a.isMatrix4?e.uniforms[s]={type:"m4",value:a.toArray()}:e.uniforms[s]={value:a}}Object.keys(this.defines).length>0&&(e.defines=this.defines),e.vertexShader=this.vertexShader,e.fragmentShader=this.fragmentShader,e.lights=this.lights,e.clipping=this.clipping;let i={};for(let s in this.extensions)this.extensions[s]===!0&&(i[s]=!0);return Object.keys(i).length>0&&(e.extensions=i),e}},to=class extends Oe{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new be,this.projectionMatrix=new be,this.projectionMatrixInverse=new be,this.coordinateSystem=ei}copy(t,e){return super.copy(t,e),this.matrixWorldInverse.copy(t.matrixWorldInverse),this.projectionMatrix.copy(t.projectionMatrix),this.projectionMatrixInverse.copy(t.projectionMatrixInverse),this.coordinateSystem=t.coordinateSystem,this}getWorldDirection(t){return super.getWorldDirection(t).negate()}updateMatrixWorld(t){super.updateMatrixWorld(t),this.matrixWorldInverse.copy(this.matrixWorld).invert()}updateWorldMatrix(t,e){super.updateWorldMatrix(t,e),this.matrixWorldInverse.copy(this.matrixWorld).invert()}clone(){return new this.constructor().copy(this)}},$i=new O,ku=new at,zu=new at,on=class extends to{constructor(t=50,e=1,i=.1,s=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=t,this.zoom=1,this.near=i,this.far=s,this.focus=10,this.aspect=e,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(t,e){return super.copy(t,e),this.fov=t.fov,this.zoom=t.zoom,this.near=t.near,this.far=t.far,this.focus=t.focus,this.aspect=t.aspect,this.view=t.view===null?null:Object.assign({},t.view),this.filmGauge=t.filmGauge,this.filmOffset=t.filmOffset,this}setFocalLength(t){let e=.5*this.getFilmHeight()/t;this.fov=ba*2*Math.atan(e),this.updateProjectionMatrix()}getFocalLength(){let t=Math.tan(mc*.5*this.fov);return .5*this.getFilmHeight()/t}getEffectiveFOV(){return ba*2*Math.atan(Math.tan(mc*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(t,e,i){$i.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),e.set($i.x,$i.y).multiplyScalar(-t/$i.z),$i.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),i.set($i.x,$i.y).multiplyScalar(-t/$i.z)}getViewSize(t,e){return this.getViewBounds(t,ku,zu),e.subVectors(zu,ku)}setViewOffset(t,e,i,s,r,a){this.aspect=t/e,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=t,this.view.fullHeight=e,this.view.offsetX=i,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let t=this.near,e=t*Math.tan(mc*.5*this.fov)/this.zoom,i=2*e,s=this.aspect*i,r=-.5*s,a=this.view;if(this.view!==null&&this.view.enabled){let l=a.fullWidth,c=a.fullHeight;r+=a.offsetX*s/l,e-=a.offsetY*i/c,s*=a.width/l,i*=a.height/c}let o=this.filmOffset;o!==0&&(r+=t*o/this.getFilmWidth()),this.projectionMatrix.makePerspective(r,r+s,e,e-i,t,this.far,this.coordinateSystem),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(t){let e=super.toJSON(t);return e.object.fov=this.fov,e.object.zoom=this.zoom,e.object.near=this.near,e.object.far=this.far,e.object.focus=this.focus,e.object.aspect=this.aspect,this.view!==null&&(e.object.view=Object.assign({},this.view)),e.object.filmGauge=this.filmGauge,e.object.filmOffset=this.filmOffset,e}},rr=-90,or=1,Ia=class extends Oe{constructor(t,e,i){super(),this.type="CubeCamera",this.renderTarget=i,this.coordinateSystem=null,this.activeMipmapLevel=0;let s=new on(rr,or,t,e);s.layers=this.layers,this.add(s);let r=new on(rr,or,t,e);r.layers=this.layers,this.add(r);let a=new on(rr,or,t,e);a.layers=this.layers,this.add(a);let o=new on(rr,or,t,e);o.layers=this.layers,this.add(o);let l=new on(rr,or,t,e);l.layers=this.layers,this.add(l);let c=new on(rr,or,t,e);c.layers=this.layers,this.add(c)}updateCoordinateSystem(){let t=this.coordinateSystem,e=this.children.concat(),[i,s,r,a,o,l]=e;for(let c of e)this.remove(c);if(t===ei)i.up.set(0,1,0),i.lookAt(1,0,0),s.up.set(0,1,0),s.lookAt(-1,0,0),r.up.set(0,0,-1),r.lookAt(0,1,0),a.up.set(0,0,1),a.lookAt(0,-1,0),o.up.set(0,1,0),o.lookAt(0,0,1),l.up.set(0,1,0),l.lookAt(0,0,-1);else if(t===$r)i.up.set(0,-1,0),i.lookAt(-1,0,0),s.up.set(0,-1,0),s.lookAt(1,0,0),r.up.set(0,0,1),r.lookAt(0,1,0),a.up.set(0,0,-1),a.lookAt(0,-1,0),o.up.set(0,-1,0),o.lookAt(0,0,1),l.up.set(0,-1,0),l.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+t);for(let c of e)this.add(c),c.updateMatrixWorld()}update(t,e){this.parent===null&&this.updateMatrixWorld();let{renderTarget:i,activeMipmapLevel:s}=this;this.coordinateSystem!==t.coordinateSystem&&(this.coordinateSystem=t.coordinateSystem,this.updateCoordinateSystem());let[r,a,o,l,c,h]=this.children,d=t.getRenderTarget(),u=t.getActiveCubeFace(),f=t.getActiveMipmapLevel(),x=t.xr.enabled;t.xr.enabled=!1;let M=i.texture.generateMipmaps;i.texture.generateMipmaps=!1,t.setRenderTarget(i,0,s),t.render(e,r),t.setRenderTarget(i,1,s),t.render(e,a),t.setRenderTarget(i,2,s),t.render(e,o),t.setRenderTarget(i,3,s),t.render(e,l),t.setRenderTarget(i,4,s),t.render(e,c),i.texture.generateMipmaps=M,t.setRenderTarget(i,5,s),t.render(e,h),t.setRenderTarget(d,u,f),t.xr.enabled=x,i.texture.needsPMREMUpdate=!0}},eo=class extends an{constructor(t,e,i,s,r,a,o,l,c,h){t=t!==void 0?t:[],e=e!==void 0?e:Ls,super(t,e,i,s,r,a,o,l,c,h),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(t){this.image=t}},La=class extends ni{constructor(t=1,e={}){super(t,t,e),this.isWebGLCubeRenderTarget=!0;let i={width:t,height:t,depth:1},s=[i,i,i,i,i,i];this.texture=new eo(s,e.mapping,e.wrapS,e.wrapT,e.magFilter,e.minFilter,e.format,e.type,e.anisotropy,e.colorSpace),this.texture.isRenderTargetTexture=!0,this.texture.generateMipmaps=e.generateMipmaps!==void 0?e.generateMipmaps:!1,this.texture.minFilter=e.minFilter!==void 0?e.minFilter:Xn}fromEquirectangularTexture(t,e){this.texture.type=e.type,this.texture.colorSpace=e.colorSpace,this.texture.generateMipmaps=e.generateMipmaps,this.texture.minFilter=e.minFilter,this.texture.magFilter=e.magFilter;let i={uniforms:{tEquirect:{value:null}},vertexShader:`

				varying vec3 vWorldDirection;

				vec3 transformDirection( in vec3 dir, in mat4 matrix ) {

					return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );

				}

				void main() {

					vWorldDirection = transformDirection( position, modelMatrix );

					#include <begin_vertex>
					#include <project_vertex>

				}
			`,fragmentShader:`

				uniform sampler2D tEquirect;

				varying vec3 vWorldDirection;

				#include <common>

				void main() {

					vec3 direction = normalize( vWorldDirection );

					vec2 sampleUV = equirectUv( direction );

					gl_FragColor = texture2D( tEquirect, sampleUV );

				}
			`},s=new Ee(5,5,5),r=new qn({name:"CubemapFromEquirect",uniforms:Fs(i.uniforms),vertexShader:i.vertexShader,fragmentShader:i.fragmentShader,side:je,blending:Ri});r.uniforms.tEquirect.value=e;let a=new $(s,r),o=e.minFilter;return e.minFilter===is&&(e.minFilter=Xn),new Ia(1,10,this).update(t,a),e.minFilter=o,a.geometry.dispose(),a.material.dispose(),this}clear(t,e,i,s){let r=t.getRenderTarget();for(let a=0;a<6;a++)t.setRenderTarget(this,a),t.clear(e,i,s);t.setRenderTarget(r)}};var no=class n{constructor(t,e=1,i=1e3){this.isFog=!0,this.name="",this.color=new Ot(t),this.near=e,this.far=i}clone(){return new n(this.color,this.near,this.far)}toJSON(){return{type:"Fog",name:this.name,color:this.color.getHex(),near:this.near,far:this.far}}},dr=class extends Oe{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new Ln,this.environmentIntensity=1,this.environmentRotation=new Ln,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__!="undefined"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(t,e){return super.copy(t,e),t.background!==null&&(this.background=t.background.clone()),t.environment!==null&&(this.environment=t.environment.clone()),t.fog!==null&&(this.fog=t.fog.clone()),this.backgroundBlurriness=t.backgroundBlurriness,this.backgroundIntensity=t.backgroundIntensity,this.backgroundRotation.copy(t.backgroundRotation),this.environmentIntensity=t.environmentIntensity,this.environmentRotation.copy(t.environmentRotation),t.overrideMaterial!==null&&(this.overrideMaterial=t.overrideMaterial.clone()),this.matrixAutoUpdate=t.matrixAutoUpdate,this}toJSON(t){let e=super.toJSON(t);return this.fog!==null&&(e.object.fog=this.fog.toJSON()),this.backgroundBlurriness>0&&(e.object.backgroundBlurriness=this.backgroundBlurriness),this.backgroundIntensity!==1&&(e.object.backgroundIntensity=this.backgroundIntensity),e.object.backgroundRotation=this.backgroundRotation.toArray(),this.environmentIntensity!==1&&(e.object.environmentIntensity=this.environmentIntensity),e.object.environmentRotation=this.environmentRotation.toArray(),e}};var Da=class extends an{constructor(t=null,e=1,i=1,s,r,a,o,l,c=xn,h=xn,d,u){super(null,a,o,l,c,h,s,r,d,u),this.isDataTexture=!0,this.image={data:t,width:e,height:i},this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}};var io=class extends gn{constructor(t,e,i,s=1){super(t,e,i),this.isInstancedBufferAttribute=!0,this.meshPerAttribute=s}copy(t){return super.copy(t),this.meshPerAttribute=t.meshPerAttribute,this}toJSON(){let t=super.toJSON();return t.meshPerAttribute=this.meshPerAttribute,t.isInstancedBufferAttribute=!0,t}},ar=new be,Gu=new be,ga=[],Vu=new ii,kp=new be,Gr=new $,Vr=new Qi,He=class extends ${constructor(t,e,i){super(t,e),this.isInstancedMesh=!0,this.instanceMatrix=new io(new Float32Array(i*16),16),this.instanceColor=null,this.morphTexture=null,this.count=i,this.boundingBox=null,this.boundingSphere=null;for(let s=0;s<i;s++)this.setMatrixAt(s,kp)}computeBoundingBox(){let t=this.geometry,e=this.count;this.boundingBox===null&&(this.boundingBox=new ii),t.boundingBox===null&&t.computeBoundingBox(),this.boundingBox.makeEmpty();for(let i=0;i<e;i++)this.getMatrixAt(i,ar),Vu.copy(t.boundingBox).applyMatrix4(ar),this.boundingBox.union(Vu)}computeBoundingSphere(){let t=this.geometry,e=this.count;this.boundingSphere===null&&(this.boundingSphere=new Qi),t.boundingSphere===null&&t.computeBoundingSphere(),this.boundingSphere.makeEmpty();for(let i=0;i<e;i++)this.getMatrixAt(i,ar),Vr.copy(t.boundingSphere).applyMatrix4(ar),this.boundingSphere.union(Vr)}copy(t,e){return super.copy(t,e),this.instanceMatrix.copy(t.instanceMatrix),t.morphTexture!==null&&(this.morphTexture=t.morphTexture.clone()),t.instanceColor!==null&&(this.instanceColor=t.instanceColor.clone()),this.count=t.count,t.boundingBox!==null&&(this.boundingBox=t.boundingBox.clone()),t.boundingSphere!==null&&(this.boundingSphere=t.boundingSphere.clone()),this}getColorAt(t,e){e.fromArray(this.instanceColor.array,t*3)}getMatrixAt(t,e){e.fromArray(this.instanceMatrix.array,t*16)}getMorphAt(t,e){let i=e.morphTargetInfluences,s=this.morphTexture.source.data.data,r=i.length+1,a=t*r+1;for(let o=0;o<i.length;o++)i[o]=s[a+o]}raycast(t,e){let i=this.matrixWorld,s=this.count;if(Gr.geometry=this.geometry,Gr.material=this.material,Gr.material!==void 0&&(this.boundingSphere===null&&this.computeBoundingSphere(),Vr.copy(this.boundingSphere),Vr.applyMatrix4(i),t.ray.intersectsSphere(Vr)!==!1))for(let r=0;r<s;r++){this.getMatrixAt(r,ar),Gu.multiplyMatrices(i,ar),Gr.matrixWorld=Gu,Gr.raycast(t,ga);for(let a=0,o=ga.length;a<o;a++){let l=ga[a];l.instanceId=r,l.object=this,e.push(l)}ga.length=0}}setColorAt(t,e){this.instanceColor===null&&(this.instanceColor=new io(new Float32Array(this.instanceMatrix.count*3).fill(1),3)),e.toArray(this.instanceColor.array,t*3)}setMatrixAt(t,e){e.toArray(this.instanceMatrix.array,t*16)}setMorphAt(t,e){let i=e.morphTargetInfluences,s=i.length+1;this.morphTexture===null&&(this.morphTexture=new Da(new Float32Array(s*this.count),s,this.count,fl,Yn));let r=this.morphTexture.source.data.data,a=0;for(let c=0;c<i.length;c++)a+=i[c];let o=this.geometry.morphTargetsRelative?1:1-a,l=s*t;r[l]=o,r.set(i,l+1)}updateMorphTargets(){}dispose(){return this.dispatchEvent({type:"dispose"}),this.morphTexture!==null&&(this.morphTexture.dispose(),this.morphTexture=null),this}},Fc=new O,zp=new O,Gp=new Qt,ti=class{constructor(t=new O(1,0,0),e=0){this.isPlane=!0,this.normal=t,this.constant=e}set(t,e){return this.normal.copy(t),this.constant=e,this}setComponents(t,e,i,s){return this.normal.set(t,e,i),this.constant=s,this}setFromNormalAndCoplanarPoint(t,e){return this.normal.copy(t),this.constant=-e.dot(this.normal),this}setFromCoplanarPoints(t,e,i){let s=Fc.subVectors(i,e).cross(zp.subVectors(t,e)).normalize();return this.setFromNormalAndCoplanarPoint(s,t),this}copy(t){return this.normal.copy(t.normal),this.constant=t.constant,this}normalize(){let t=1/this.normal.length();return this.normal.multiplyScalar(t),this.constant*=t,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(t){return this.normal.dot(t)+this.constant}distanceToSphere(t){return this.distanceToPoint(t.center)-t.radius}projectPoint(t,e){return e.copy(t).addScaledVector(this.normal,-this.distanceToPoint(t))}intersectLine(t,e){let i=t.delta(Fc),s=this.normal.dot(i);if(s===0)return this.distanceToPoint(t.start)===0?e.copy(t.start):null;let r=-(t.start.dot(this.normal)+this.constant)/s;return r<0||r>1?null:e.copy(t.start).addScaledVector(i,r)}intersectsLine(t){let e=this.distanceToPoint(t.start),i=this.distanceToPoint(t.end);return e<0&&i>0||i<0&&e>0}intersectsBox(t){return t.intersectsPlane(this)}intersectsSphere(t){return t.intersectsPlane(this)}coplanarPoint(t){return t.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(t,e){let i=e||Gp.getNormalMatrix(t),s=this.coplanarPoint(Fc).applyMatrix4(t),r=this.normal.applyMatrix3(i).normalize();return this.constant=-s.dot(r),this}translate(t){return this.constant-=t.dot(this.normal),this}equals(t){return t.normal.equals(this.normal)&&t.constant===this.constant}clone(){return new this.constructor().copy(this)}},Ms=new Qi,xa=new O,fr=class{constructor(t=new ti,e=new ti,i=new ti,s=new ti,r=new ti,a=new ti){this.planes=[t,e,i,s,r,a]}set(t,e,i,s,r,a){let o=this.planes;return o[0].copy(t),o[1].copy(e),o[2].copy(i),o[3].copy(s),o[4].copy(r),o[5].copy(a),this}copy(t){let e=this.planes;for(let i=0;i<6;i++)e[i].copy(t.planes[i]);return this}setFromProjectionMatrix(t,e=ei){let i=this.planes,s=t.elements,r=s[0],a=s[1],o=s[2],l=s[3],c=s[4],h=s[5],d=s[6],u=s[7],f=s[8],x=s[9],M=s[10],m=s[11],p=s[12],S=s[13],E=s[14],g=s[15];if(i[0].setComponents(l-r,u-c,m-f,g-p).normalize(),i[1].setComponents(l+r,u+c,m+f,g+p).normalize(),i[2].setComponents(l+a,u+h,m+x,g+S).normalize(),i[3].setComponents(l-a,u-h,m-x,g-S).normalize(),i[4].setComponents(l-o,u-d,m-M,g-E).normalize(),e===ei)i[5].setComponents(l+o,u+d,m+M,g+E).normalize();else if(e===$r)i[5].setComponents(o,d,M,E).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+e);return this}intersectsObject(t){if(t.boundingSphere!==void 0)t.boundingSphere===null&&t.computeBoundingSphere(),Ms.copy(t.boundingSphere).applyMatrix4(t.matrixWorld);else{let e=t.geometry;e.boundingSphere===null&&e.computeBoundingSphere(),Ms.copy(e.boundingSphere).applyMatrix4(t.matrixWorld)}return this.intersectsSphere(Ms)}intersectsSprite(t){return Ms.center.set(0,0,0),Ms.radius=.7071067811865476,Ms.applyMatrix4(t.matrixWorld),this.intersectsSphere(Ms)}intersectsSphere(t){let e=this.planes,i=t.center,s=-t.radius;for(let r=0;r<6;r++)if(e[r].distanceToPoint(i)<s)return!1;return!0}intersectsBox(t){let e=this.planes;for(let i=0;i<6;i++){let s=e[i];if(xa.x=s.normal.x>0?t.max.x:t.min.x,xa.y=s.normal.y>0?t.max.y:t.min.y,xa.z=s.normal.z>0?t.max.z:t.min.z,s.distanceToPoint(xa)<0)return!1}return!0}containsPoint(t){let e=this.planes;for(let i=0;i<6;i++)if(e[i].distanceToPoint(t)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}};var he=class extends Oe{constructor(){super(),this.isGroup=!0,this.type="Group"}};var Qe=class extends an{constructor(t,e,i,s,r,a,o,l,c){super(t,e,i,s,r,a,o,l,c),this.isCanvasTexture=!0,this.needsUpdate=!0}},so=class extends an{constructor(t,e,i,s,r,a,o,l,c,h=Ss){if(h!==Ss&&h!==bs)throw new Error("DepthTexture format must be either THREE.DepthFormat or THREE.DepthStencilFormat");i===void 0&&h===Ss&&(i=ss),i===void 0&&h===bs&&(i=Us),super(null,s,r,a,o,l,h,i,c),this.isDepthTexture=!0,this.image={width:t,height:e},this.magFilter=o!==void 0?o:xn,this.minFilter=l!==void 0?l:xn,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(t){return super.copy(t),this.compareFunction=t.compareFunction,this}toJSON(t){let e=super.toJSON(t);return this.compareFunction!==null&&(e.compareFunction=this.compareFunction),e}},bn=class{constructor(){this.type="Curve",this.arcLengthDivisions=200}getPoint(){return console.warn("THREE.Curve: .getPoint() not implemented."),null}getPointAt(t,e){let i=this.getUtoTmapping(t);return this.getPoint(i,e)}getPoints(t=5){let e=[];for(let i=0;i<=t;i++)e.push(this.getPoint(i/t));return e}getSpacedPoints(t=5){let e=[];for(let i=0;i<=t;i++)e.push(this.getPointAt(i/t));return e}getLength(){let t=this.getLengths();return t[t.length-1]}getLengths(t=this.arcLengthDivisions){if(this.cacheArcLengths&&this.cacheArcLengths.length===t+1&&!this.needsUpdate)return this.cacheArcLengths;this.needsUpdate=!1;let e=[],i,s=this.getPoint(0),r=0;e.push(0);for(let a=1;a<=t;a++)i=this.getPoint(a/t),r+=i.distanceTo(s),e.push(r),s=i;return this.cacheArcLengths=e,e}updateArcLengths(){this.needsUpdate=!0,this.getLengths()}getUtoTmapping(t,e){let i=this.getLengths(),s=0,r=i.length,a;e?a=e:a=t*i[r-1];let o=0,l=r-1,c;for(;o<=l;)if(s=Math.floor(o+(l-o)/2),c=i[s]-a,c<0)o=s+1;else if(c>0)l=s-1;else{l=s;break}if(s=l,i[s]===a)return s/(r-1);let h=i[s],u=i[s+1]-h,f=(a-h)/u;return(s+f)/(r-1)}getTangent(t,e){let s=t-1e-4,r=t+1e-4;s<0&&(s=0),r>1&&(r=1);let a=this.getPoint(s),o=this.getPoint(r),l=e||(a.isVector2?new at:new O);return l.copy(o).sub(a).normalize(),l}getTangentAt(t,e){let i=this.getUtoTmapping(t);return this.getTangent(i,e)}computeFrenetFrames(t,e){let i=new O,s=[],r=[],a=[],o=new O,l=new be;for(let f=0;f<=t;f++){let x=f/t;s[f]=this.getTangentAt(x,new O)}r[0]=new O,a[0]=new O;let c=Number.MAX_VALUE,h=Math.abs(s[0].x),d=Math.abs(s[0].y),u=Math.abs(s[0].z);h<=c&&(c=h,i.set(1,0,0)),d<=c&&(c=d,i.set(0,1,0)),u<=c&&i.set(0,0,1),o.crossVectors(s[0],i).normalize(),r[0].crossVectors(s[0],o),a[0].crossVectors(s[0],r[0]);for(let f=1;f<=t;f++){if(r[f]=r[f-1].clone(),a[f]=a[f-1].clone(),o.crossVectors(s[f-1],s[f]),o.length()>Number.EPSILON){o.normalize();let x=Math.acos(ie(s[f-1].dot(s[f]),-1,1));r[f].applyMatrix4(l.makeRotationAxis(o,x))}a[f].crossVectors(s[f],r[f])}if(e===!0){let f=Math.acos(ie(r[0].dot(r[t]),-1,1));f/=t,s[0].dot(o.crossVectors(r[0],r[t]))>0&&(f=-f);for(let x=1;x<=t;x++)r[x].applyMatrix4(l.makeRotationAxis(s[x],f*x)),a[x].crossVectors(s[x],r[x])}return{tangents:s,normals:r,binormals:a}}clone(){return new this.constructor().copy(this)}copy(t){return this.arcLengthDivisions=t.arcLengthDivisions,this}toJSON(){let t={metadata:{version:4.6,type:"Curve",generator:"Curve.toJSON"}};return t.arcLengthDivisions=this.arcLengthDivisions,t.type=this.type,t}fromJSON(t){return this.arcLengthDivisions=t.arcLengthDivisions,this}},pr=class extends bn{constructor(t=0,e=0,i=1,s=1,r=0,a=Math.PI*2,o=!1,l=0){super(),this.isEllipseCurve=!0,this.type="EllipseCurve",this.aX=t,this.aY=e,this.xRadius=i,this.yRadius=s,this.aStartAngle=r,this.aEndAngle=a,this.aClockwise=o,this.aRotation=l}getPoint(t,e=new at){let i=e,s=Math.PI*2,r=this.aEndAngle-this.aStartAngle,a=Math.abs(r)<Number.EPSILON;for(;r<0;)r+=s;for(;r>s;)r-=s;r<Number.EPSILON&&(a?r=0:r=s),this.aClockwise===!0&&!a&&(r===s?r=-s:r=r-s);let o=this.aStartAngle+t*r,l=this.aX+this.xRadius*Math.cos(o),c=this.aY+this.yRadius*Math.sin(o);if(this.aRotation!==0){let h=Math.cos(this.aRotation),d=Math.sin(this.aRotation),u=l-this.aX,f=c-this.aY;l=u*h-f*d+this.aX,c=u*d+f*h+this.aY}return i.set(l,c)}copy(t){return super.copy(t),this.aX=t.aX,this.aY=t.aY,this.xRadius=t.xRadius,this.yRadius=t.yRadius,this.aStartAngle=t.aStartAngle,this.aEndAngle=t.aEndAngle,this.aClockwise=t.aClockwise,this.aRotation=t.aRotation,this}toJSON(){let t=super.toJSON();return t.aX=this.aX,t.aY=this.aY,t.xRadius=this.xRadius,t.yRadius=this.yRadius,t.aStartAngle=this.aStartAngle,t.aEndAngle=this.aEndAngle,t.aClockwise=this.aClockwise,t.aRotation=this.aRotation,t}fromJSON(t){return super.fromJSON(t),this.aX=t.aX,this.aY=t.aY,this.xRadius=t.xRadius,this.yRadius=t.yRadius,this.aStartAngle=t.aStartAngle,this.aEndAngle=t.aEndAngle,this.aClockwise=t.aClockwise,this.aRotation=t.aRotation,this}},Ua=class extends pr{constructor(t,e,i,s,r,a){super(t,e,i,i,s,r,a),this.isArcCurve=!0,this.type="ArcCurve"}};function gh(){let n=0,t=0,e=0,i=0;function s(r,a,o,l){n=r,t=o,e=-3*r+3*a-2*o-l,i=2*r-2*a+o+l}return{initCatmullRom:function(r,a,o,l,c){s(a,o,c*(o-r),c*(l-a))},initNonuniformCatmullRom:function(r,a,o,l,c,h,d){let u=(a-r)/c-(o-r)/(c+h)+(o-a)/h,f=(o-a)/h-(l-a)/(h+d)+(l-o)/d;u*=h,f*=h,s(a,o,u,f)},calc:function(r){let a=r*r,o=a*r;return n+t*r+e*a+i*o}}}var ya=new O,Oc=new gh,Hc=new gh,Bc=new gh,mr=class extends bn{constructor(t=[],e=!1,i="centripetal",s=.5){super(),this.isCatmullRomCurve3=!0,this.type="CatmullRomCurve3",this.points=t,this.closed=e,this.curveType=i,this.tension=s}getPoint(t,e=new O){let i=e,s=this.points,r=s.length,a=(r-(this.closed?0:1))*t,o=Math.floor(a),l=a-o;this.closed?o+=o>0?0:(Math.floor(Math.abs(o)/r)+1)*r:l===0&&o===r-1&&(o=r-2,l=1);let c,h;this.closed||o>0?c=s[(o-1)%r]:(ya.subVectors(s[0],s[1]).add(s[0]),c=ya);let d=s[o%r],u=s[(o+1)%r];if(this.closed||o+2<r?h=s[(o+2)%r]:(ya.subVectors(s[r-1],s[r-2]).add(s[r-1]),h=ya),this.curveType==="centripetal"||this.curveType==="chordal"){let f=this.curveType==="chordal"?.5:.25,x=Math.pow(c.distanceToSquared(d),f),M=Math.pow(d.distanceToSquared(u),f),m=Math.pow(u.distanceToSquared(h),f);M<1e-4&&(M=1),x<1e-4&&(x=M),m<1e-4&&(m=M),Oc.initNonuniformCatmullRom(c.x,d.x,u.x,h.x,x,M,m),Hc.initNonuniformCatmullRom(c.y,d.y,u.y,h.y,x,M,m),Bc.initNonuniformCatmullRom(c.z,d.z,u.z,h.z,x,M,m)}else this.curveType==="catmullrom"&&(Oc.initCatmullRom(c.x,d.x,u.x,h.x,this.tension),Hc.initCatmullRom(c.y,d.y,u.y,h.y,this.tension),Bc.initCatmullRom(c.z,d.z,u.z,h.z,this.tension));return i.set(Oc.calc(l),Hc.calc(l),Bc.calc(l)),i}copy(t){super.copy(t),this.points=[];for(let e=0,i=t.points.length;e<i;e++){let s=t.points[e];this.points.push(s.clone())}return this.closed=t.closed,this.curveType=t.curveType,this.tension=t.tension,this}toJSON(){let t=super.toJSON();t.points=[];for(let e=0,i=this.points.length;e<i;e++){let s=this.points[e];t.points.push(s.toArray())}return t.closed=this.closed,t.curveType=this.curveType,t.tension=this.tension,t}fromJSON(t){super.fromJSON(t),this.points=[];for(let e=0,i=t.points.length;e<i;e++){let s=t.points[e];this.points.push(new O().fromArray(s))}return this.closed=t.closed,this.curveType=t.curveType,this.tension=t.tension,this}};function Wu(n,t,e,i,s){let r=(i-t)*.5,a=(s-e)*.5,o=n*n,l=n*o;return(2*e-2*i+r+a)*l+(-3*e+3*i-2*r-a)*o+r*n+e}function Vp(n,t){let e=1-n;return e*e*t}function Wp(n,t){return 2*(1-n)*n*t}function Xp(n,t){return n*n*t}function Wr(n,t,e,i){return Vp(n,t)+Wp(n,e)+Xp(n,i)}function qp(n,t){let e=1-n;return e*e*e*t}function Yp(n,t){let e=1-n;return 3*e*e*n*t}function $p(n,t){return 3*(1-n)*n*n*t}function Zp(n,t){return n*n*n*t}function Xr(n,t,e,i,s){return qp(n,t)+Yp(n,e)+$p(n,i)+Zp(n,s)}var ro=class extends bn{constructor(t=new at,e=new at,i=new at,s=new at){super(),this.isCubicBezierCurve=!0,this.type="CubicBezierCurve",this.v0=t,this.v1=e,this.v2=i,this.v3=s}getPoint(t,e=new at){let i=e,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return i.set(Xr(t,s.x,r.x,a.x,o.x),Xr(t,s.y,r.y,a.y,o.y)),i}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this.v3.copy(t.v3),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t.v3=this.v3.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this.v3.fromArray(t.v3),this}},Na=class extends bn{constructor(t=new O,e=new O,i=new O,s=new O){super(),this.isCubicBezierCurve3=!0,this.type="CubicBezierCurve3",this.v0=t,this.v1=e,this.v2=i,this.v3=s}getPoint(t,e=new O){let i=e,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return i.set(Xr(t,s.x,r.x,a.x,o.x),Xr(t,s.y,r.y,a.y,o.y),Xr(t,s.z,r.z,a.z,o.z)),i}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this.v3.copy(t.v3),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t.v3=this.v3.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this.v3.fromArray(t.v3),this}},oo=class extends bn{constructor(t=new at,e=new at){super(),this.isLineCurve=!0,this.type="LineCurve",this.v1=t,this.v2=e}getPoint(t,e=new at){let i=e;return t===1?i.copy(this.v2):(i.copy(this.v2).sub(this.v1),i.multiplyScalar(t).add(this.v1)),i}getPointAt(t,e){return this.getPoint(t,e)}getTangent(t,e=new at){return e.subVectors(this.v2,this.v1).normalize()}getTangentAt(t,e){return this.getTangent(t,e)}copy(t){return super.copy(t),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},Fa=class extends bn{constructor(t=new O,e=new O){super(),this.isLineCurve3=!0,this.type="LineCurve3",this.v1=t,this.v2=e}getPoint(t,e=new O){let i=e;return t===1?i.copy(this.v2):(i.copy(this.v2).sub(this.v1),i.multiplyScalar(t).add(this.v1)),i}getPointAt(t,e){return this.getPoint(t,e)}getTangent(t,e=new O){return e.subVectors(this.v2,this.v1).normalize()}getTangentAt(t,e){return this.getTangent(t,e)}copy(t){return super.copy(t),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},ao=class extends bn{constructor(t=new at,e=new at,i=new at){super(),this.isQuadraticBezierCurve=!0,this.type="QuadraticBezierCurve",this.v0=t,this.v1=e,this.v2=i}getPoint(t,e=new at){let i=e,s=this.v0,r=this.v1,a=this.v2;return i.set(Wr(t,s.x,r.x,a.x),Wr(t,s.y,r.y,a.y)),i}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},lo=class extends bn{constructor(t=new O,e=new O,i=new O){super(),this.isQuadraticBezierCurve3=!0,this.type="QuadraticBezierCurve3",this.v0=t,this.v1=e,this.v2=i}getPoint(t,e=new O){let i=e,s=this.v0,r=this.v1,a=this.v2;return i.set(Wr(t,s.x,r.x,a.x),Wr(t,s.y,r.y,a.y),Wr(t,s.z,r.z,a.z)),i}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},co=class extends bn{constructor(t=[]){super(),this.isSplineCurve=!0,this.type="SplineCurve",this.points=t}getPoint(t,e=new at){let i=e,s=this.points,r=(s.length-1)*t,a=Math.floor(r),o=r-a,l=s[a===0?a:a-1],c=s[a],h=s[a>s.length-2?s.length-1:a+1],d=s[a>s.length-3?s.length-1:a+2];return i.set(Wu(o,l.x,c.x,h.x,d.x),Wu(o,l.y,c.y,h.y,d.y)),i}copy(t){super.copy(t),this.points=[];for(let e=0,i=t.points.length;e<i;e++){let s=t.points[e];this.points.push(s.clone())}return this}toJSON(){let t=super.toJSON();t.points=[];for(let e=0,i=this.points.length;e<i;e++){let s=this.points[e];t.points.push(s.toArray())}return t}fromJSON(t){super.fromJSON(t),this.points=[];for(let e=0,i=t.points.length;e<i;e++){let s=t.points[e];this.points.push(new at().fromArray(s))}return this}},Oa=Object.freeze({__proto__:null,ArcCurve:Ua,CatmullRomCurve3:mr,CubicBezierCurve:ro,CubicBezierCurve3:Na,EllipseCurve:pr,LineCurve:oo,LineCurve3:Fa,QuadraticBezierCurve:ao,QuadraticBezierCurve3:lo,SplineCurve:co}),Ha=class extends bn{constructor(){super(),this.type="CurvePath",this.curves=[],this.autoClose=!1}add(t){this.curves.push(t)}closePath(){let t=this.curves[0].getPoint(0),e=this.curves[this.curves.length-1].getPoint(1);if(!t.equals(e)){let i=t.isVector2===!0?"LineCurve":"LineCurve3";this.curves.push(new Oa[i](e,t))}return this}getPoint(t,e){let i=t*this.getLength(),s=this.getCurveLengths(),r=0;for(;r<s.length;){if(s[r]>=i){let a=s[r]-i,o=this.curves[r],l=o.getLength(),c=l===0?0:1-a/l;return o.getPointAt(c,e)}r++}return null}getLength(){let t=this.getCurveLengths();return t[t.length-1]}updateArcLengths(){this.needsUpdate=!0,this.cacheLengths=null,this.getCurveLengths()}getCurveLengths(){if(this.cacheLengths&&this.cacheLengths.length===this.curves.length)return this.cacheLengths;let t=[],e=0;for(let i=0,s=this.curves.length;i<s;i++)e+=this.curves[i].getLength(),t.push(e);return this.cacheLengths=t,t}getSpacedPoints(t=40){let e=[];for(let i=0;i<=t;i++)e.push(this.getPoint(i/t));return this.autoClose&&e.push(e[0]),e}getPoints(t=12){let e=[],i;for(let s=0,r=this.curves;s<r.length;s++){let a=r[s],o=a.isEllipseCurve?t*2:a.isLineCurve||a.isLineCurve3?1:a.isSplineCurve?t*a.points.length:t,l=a.getPoints(o);for(let c=0;c<l.length;c++){let h=l[c];i&&i.equals(h)||(e.push(h),i=h)}}return this.autoClose&&e.length>1&&!e[e.length-1].equals(e[0])&&e.push(e[0]),e}copy(t){super.copy(t),this.curves=[];for(let e=0,i=t.curves.length;e<i;e++){let s=t.curves[e];this.curves.push(s.clone())}return this.autoClose=t.autoClose,this}toJSON(){let t=super.toJSON();t.autoClose=this.autoClose,t.curves=[];for(let e=0,i=this.curves.length;e<i;e++){let s=this.curves[e];t.curves.push(s.toJSON())}return t}fromJSON(t){super.fromJSON(t),this.autoClose=t.autoClose,this.curves=[];for(let e=0,i=t.curves.length;e<i;e++){let s=t.curves[e];this.curves.push(new Oa[s.type]().fromJSON(s))}return this}},Rs=class extends Ha{constructor(t){super(),this.type="Path",this.currentPoint=new at,t&&this.setFromPoints(t)}setFromPoints(t){this.moveTo(t[0].x,t[0].y);for(let e=1,i=t.length;e<i;e++)this.lineTo(t[e].x,t[e].y);return this}moveTo(t,e){return this.currentPoint.set(t,e),this}lineTo(t,e){let i=new oo(this.currentPoint.clone(),new at(t,e));return this.curves.push(i),this.currentPoint.set(t,e),this}quadraticCurveTo(t,e,i,s){let r=new ao(this.currentPoint.clone(),new at(t,e),new at(i,s));return this.curves.push(r),this.currentPoint.set(i,s),this}bezierCurveTo(t,e,i,s,r,a){let o=new ro(this.currentPoint.clone(),new at(t,e),new at(i,s),new at(r,a));return this.curves.push(o),this.currentPoint.set(r,a),this}splineThru(t){let e=[this.currentPoint.clone()].concat(t),i=new co(e);return this.curves.push(i),this.currentPoint.copy(t[t.length-1]),this}arc(t,e,i,s,r,a){let o=this.currentPoint.x,l=this.currentPoint.y;return this.absarc(t+o,e+l,i,s,r,a),this}absarc(t,e,i,s,r,a){return this.absellipse(t,e,i,i,s,r,a),this}ellipse(t,e,i,s,r,a,o,l){let c=this.currentPoint.x,h=this.currentPoint.y;return this.absellipse(t+c,e+h,i,s,r,a,o,l),this}absellipse(t,e,i,s,r,a,o,l){let c=new pr(t,e,i,s,r,a,o,l);if(this.curves.length>0){let d=c.getPoint(0);d.equals(this.currentPoint)||this.lineTo(d.x,d.y)}this.curves.push(c);let h=c.getPoint(1);return this.currentPoint.copy(h),this}copy(t){return super.copy(t),this.currentPoint.copy(t.currentPoint),this}toJSON(){let t=super.toJSON();return t.currentPoint=this.currentPoint.toArray(),t}fromJSON(t){return super.fromJSON(t),this.currentPoint.fromArray(t.currentPoint),this}},ji=class n extends qe{constructor(t=[new at(0,-.5),new at(.5,0),new at(0,.5)],e=12,i=0,s=Math.PI*2){super(),this.type="LatheGeometry",this.parameters={points:t,segments:e,phiStart:i,phiLength:s},e=Math.floor(e),s=ie(s,0,Math.PI*2);let r=[],a=[],o=[],l=[],c=[],h=1/e,d=new O,u=new at,f=new O,x=new O,M=new O,m=0,p=0;for(let S=0;S<=t.length-1;S++)switch(S){case 0:m=t[S+1].x-t[S].x,p=t[S+1].y-t[S].y,f.x=p*1,f.y=-m,f.z=p*0,M.copy(f),f.normalize(),l.push(f.x,f.y,f.z);break;case t.length-1:l.push(M.x,M.y,M.z);break;default:m=t[S+1].x-t[S].x,p=t[S+1].y-t[S].y,f.x=p*1,f.y=-m,f.z=p*0,x.copy(f),f.x+=M.x,f.y+=M.y,f.z+=M.z,f.normalize(),l.push(f.x,f.y,f.z),M.copy(x)}for(let S=0;S<=e;S++){let E=i+S*h*s,g=Math.sin(E),C=Math.cos(E);for(let A=0;A<=t.length-1;A++){d.x=t[A].x*g,d.y=t[A].y,d.z=t[A].x*C,a.push(d.x,d.y,d.z),u.x=S/e,u.y=A/(t.length-1),o.push(u.x,u.y);let _=l[3*A+0]*g,T=l[3*A+1],v=l[3*A+0]*C;c.push(_,T,v)}}for(let S=0;S<e;S++)for(let E=0;E<t.length-1;E++){let g=E+S*t.length,C=g,A=g+t.length,_=g+t.length+1,T=g+1;r.push(C,A,T),r.push(_,T,A)}this.setIndex(r),this.setAttribute("position",new se(a,3)),this.setAttribute("uv",new se(o,2)),this.setAttribute("normal",new se(c,3))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.points,t.segments,t.phiStart,t.phiLength)}};var yn=class n extends qe{constructor(t=1,e=32,i=0,s=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:t,segments:e,thetaStart:i,thetaLength:s},e=Math.max(3,e);let r=[],a=[],o=[],l=[],c=new O,h=new at;a.push(0,0,0),o.push(0,0,1),l.push(.5,.5);for(let d=0,u=3;d<=e;d++,u+=3){let f=i+d/e*s;c.x=t*Math.cos(f),c.y=t*Math.sin(f),a.push(c.x,c.y,c.z),o.push(0,0,1),h.x=(a[u]/t+1)/2,h.y=(a[u+1]/t+1)/2,l.push(h.x,h.y)}for(let d=1;d<=e;d++)r.push(d,d+1,0);this.setIndex(r),this.setAttribute("position",new se(a,3)),this.setAttribute("normal",new se(o,3)),this.setAttribute("uv",new se(l,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.radius,t.segments,t.thetaStart,t.thetaLength)}},oe=class n extends qe{constructor(t=1,e=1,i=1,s=32,r=1,a=!1,o=0,l=Math.PI*2){super(),this.type="CylinderGeometry",this.parameters={radiusTop:t,radiusBottom:e,height:i,radialSegments:s,heightSegments:r,openEnded:a,thetaStart:o,thetaLength:l};let c=this;s=Math.floor(s),r=Math.floor(r);let h=[],d=[],u=[],f=[],x=0,M=[],m=i/2,p=0;S(),a===!1&&(t>0&&E(!0),e>0&&E(!1)),this.setIndex(h),this.setAttribute("position",new se(d,3)),this.setAttribute("normal",new se(u,3)),this.setAttribute("uv",new se(f,2));function S(){let g=new O,C=new O,A=0,_=(e-t)/i;for(let T=0;T<=r;T++){let v=[],y=T/r,w=y*(e-t)+t;for(let P=0;P<=s;P++){let D=P/s,N=D*l+o,H=Math.sin(N),U=Math.cos(N);C.x=w*H,C.y=-y*i+m,C.z=w*U,d.push(C.x,C.y,C.z),g.set(H,_,U).normalize(),u.push(g.x,g.y,g.z),f.push(D,1-y),v.push(x++)}M.push(v)}for(let T=0;T<s;T++)for(let v=0;v<r;v++){let y=M[v][T],w=M[v+1][T],P=M[v+1][T+1],D=M[v][T+1];(t>0||v!==0)&&(h.push(y,w,D),A+=3),(e>0||v!==r-1)&&(h.push(w,P,D),A+=3)}c.addGroup(p,A,0),p+=A}function E(g){let C=x,A=new at,_=new O,T=0,v=g===!0?t:e,y=g===!0?1:-1;for(let P=1;P<=s;P++)d.push(0,m*y,0),u.push(0,y,0),f.push(.5,.5),x++;let w=x;for(let P=0;P<=s;P++){let N=P/s*l+o,H=Math.cos(N),U=Math.sin(N);_.x=v*U,_.y=m*y,_.z=v*H,d.push(_.x,_.y,_.z),u.push(0,y,0),A.x=H*.5+.5,A.y=U*.5*y+.5,f.push(A.x,A.y),x++}for(let P=0;P<s;P++){let D=C+P,N=w+P;g===!0?h.push(N,N+1,D):h.push(N+1,N,D),T+=3}c.addGroup(p,T,g===!0?1:2),p+=T}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.radiusTop,t.radiusBottom,t.height,t.radialSegments,t.heightSegments,t.openEnded,t.thetaStart,t.thetaLength)}},un=class n extends oe{constructor(t=1,e=1,i=32,s=1,r=!1,a=0,o=Math.PI*2){super(0,t,e,i,s,r,a,o),this.type="ConeGeometry",this.parameters={radius:t,height:e,radialSegments:i,heightSegments:s,openEnded:r,thetaStart:a,thetaLength:o}}static fromJSON(t){return new n(t.radius,t.height,t.radialSegments,t.heightSegments,t.openEnded,t.thetaStart,t.thetaLength)}},ho=class n extends qe{constructor(t=[],e=[],i=1,s=0){super(),this.type="PolyhedronGeometry",this.parameters={vertices:t,indices:e,radius:i,detail:s};let r=[],a=[];o(s),c(i),h(),this.setAttribute("position",new se(r,3)),this.setAttribute("normal",new se(r.slice(),3)),this.setAttribute("uv",new se(a,2)),s===0?this.computeVertexNormals():this.normalizeNormals();function o(S){let E=new O,g=new O,C=new O;for(let A=0;A<e.length;A+=3)f(e[A+0],E),f(e[A+1],g),f(e[A+2],C),l(E,g,C,S)}function l(S,E,g,C){let A=C+1,_=[];for(let T=0;T<=A;T++){_[T]=[];let v=S.clone().lerp(g,T/A),y=E.clone().lerp(g,T/A),w=A-T;for(let P=0;P<=w;P++)P===0&&T===A?_[T][P]=v:_[T][P]=v.clone().lerp(y,P/w)}for(let T=0;T<A;T++)for(let v=0;v<2*(A-T)-1;v++){let y=Math.floor(v/2);v%2===0?(u(_[T][y+1]),u(_[T+1][y]),u(_[T][y])):(u(_[T][y+1]),u(_[T+1][y+1]),u(_[T+1][y]))}}function c(S){let E=new O;for(let g=0;g<r.length;g+=3)E.x=r[g+0],E.y=r[g+1],E.z=r[g+2],E.normalize().multiplyScalar(S),r[g+0]=E.x,r[g+1]=E.y,r[g+2]=E.z}function h(){let S=new O;for(let E=0;E<r.length;E+=3){S.x=r[E+0],S.y=r[E+1],S.z=r[E+2];let g=m(S)/2/Math.PI+.5,C=p(S)/Math.PI+.5;a.push(g,1-C)}x(),d()}function d(){for(let S=0;S<a.length;S+=6){let E=a[S+0],g=a[S+2],C=a[S+4],A=Math.max(E,g,C),_=Math.min(E,g,C);A>.9&&_<.1&&(E<.2&&(a[S+0]+=1),g<.2&&(a[S+2]+=1),C<.2&&(a[S+4]+=1))}}function u(S){r.push(S.x,S.y,S.z)}function f(S,E){let g=S*3;E.x=t[g+0],E.y=t[g+1],E.z=t[g+2]}function x(){let S=new O,E=new O,g=new O,C=new O,A=new at,_=new at,T=new at;for(let v=0,y=0;v<r.length;v+=9,y+=6){S.set(r[v+0],r[v+1],r[v+2]),E.set(r[v+3],r[v+4],r[v+5]),g.set(r[v+6],r[v+7],r[v+8]),A.set(a[y+0],a[y+1]),_.set(a[y+2],a[y+3]),T.set(a[y+4],a[y+5]),C.copy(S).add(E).add(g).divideScalar(3);let w=m(C);M(A,y+0,S,w),M(_,y+2,E,w),M(T,y+4,g,w)}}function M(S,E,g,C){C<0&&S.x===1&&(a[E]=S.x-1),g.x===0&&g.z===0&&(a[E]=C/2/Math.PI+.5)}function m(S){return Math.atan2(S.z,-S.x)}function p(S){return Math.atan2(-S.y,Math.sqrt(S.x*S.x+S.z*S.z))}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.vertices,t.indices,t.radius,t.details)}},Cs=class n extends ho{constructor(t=1,e=0){let i=(1+Math.sqrt(5))/2,s=1/i,r=[-1,-1,-1,-1,-1,1,-1,1,-1,-1,1,1,1,-1,-1,1,-1,1,1,1,-1,1,1,1,0,-s,-i,0,-s,i,0,s,-i,0,s,i,-s,-i,0,-s,i,0,s,-i,0,s,i,0,-i,0,-s,i,0,-s,-i,0,s,i,0,s],a=[3,11,7,3,7,15,3,15,13,7,19,17,7,17,6,7,6,15,17,4,8,17,8,10,17,10,6,8,0,16,8,16,2,8,2,10,0,12,1,0,1,18,0,18,16,6,10,2,6,2,13,6,13,15,2,16,18,2,18,3,2,3,13,18,1,9,18,9,11,18,11,3,4,14,12,4,12,0,4,0,8,11,9,5,11,5,19,11,19,7,19,5,14,19,14,4,19,4,17,1,12,14,1,14,5,1,5,9];super(r,a,t,e),this.type="DodecahedronGeometry",this.parameters={radius:t,detail:e}}static fromJSON(t){return new n(t.radius,t.detail)}};var ln=class extends Rs{constructor(t){super(t),this.uuid=Mr(),this.type="Shape",this.holes=[]}getPointsHoles(t){let e=[];for(let i=0,s=this.holes.length;i<s;i++)e[i]=this.holes[i].getPoints(t);return e}extractPoints(t){return{shape:this.getPoints(t),holes:this.getPointsHoles(t)}}copy(t){super.copy(t),this.holes=[];for(let e=0,i=t.holes.length;e<i;e++){let s=t.holes[e];this.holes.push(s.clone())}return this}toJSON(){let t=super.toJSON();t.uuid=this.uuid,t.holes=[];for(let e=0,i=this.holes.length;e<i;e++){let s=this.holes[e];t.holes.push(s.toJSON())}return t}fromJSON(t){super.fromJSON(t),this.uuid=t.uuid,this.holes=[];for(let e=0,i=t.holes.length;e<i;e++){let s=t.holes[e];this.holes.push(new Rs().fromJSON(s))}return this}},Jp={triangulate:function(n,t,e=2){let i=t&&t.length,s=i?t[0]*e:n.length,r=zd(n,0,s,e,!0),a=[];if(!r||r.next===r.prev)return a;let o,l,c,h,d,u,f;if(i&&(r=em(n,t,r,e)),n.length>80*e){o=c=n[0],l=h=n[1];for(let x=e;x<s;x+=e)d=n[x],u=n[x+1],d<o&&(o=d),u<l&&(l=u),d>c&&(c=d),u>h&&(h=u);f=Math.max(c-o,h-l),f=f!==0?32767/f:0}return uo(r,a,e,o,l,f,0),a}};function zd(n,t,e,i,s){let r,a;if(s===dm(n,t,e,i)>0)for(r=t;r<e;r+=i)a=Xu(r,n[r],n[r+1],a);else for(r=e-i;r>=t;r-=i)a=Xu(r,n[r],n[r+1],a);return a&&Wl(a,a.next)&&(po(a),a=a.next),a}function Ps(n,t){if(!n)return n;t||(t=n);let e=n,i;do if(i=!1,!e.steiner&&(Wl(e,e.next)||Ie(e.prev,e,e.next)===0)){if(po(e),e=t=e.prev,e===e.next)break;i=!0}else e=e.next;while(i||e!==t);return t}function uo(n,t,e,i,s,r,a){if(!n)return;!a&&r&&om(n,i,s,r);let o=n,l,c;for(;n.prev!==n.next;){if(l=n.prev,c=n.next,r?Qp(n,i,s,r):Kp(n)){t.push(l.i/e|0),t.push(n.i/e|0),t.push(c.i/e|0),po(n),n=c.next,o=c.next;continue}if(n=c,n===o){a?a===1?(n=jp(Ps(n),t,e),uo(n,t,e,i,s,r,2)):a===2&&tm(n,t,e,i,s,r):uo(Ps(n),t,e,i,s,r,1);break}}}function Kp(n){let t=n.prev,e=n,i=n.next;if(Ie(t,e,i)>=0)return!1;let s=t.x,r=e.x,a=i.x,o=t.y,l=e.y,c=i.y,h=s<r?s<a?s:a:r<a?r:a,d=o<l?o<c?o:c:l<c?l:c,u=s>r?s>a?s:a:r>a?r:a,f=o>l?o>c?o:c:l>c?l:c,x=i.next;for(;x!==t;){if(x.x>=h&&x.x<=u&&x.y>=d&&x.y<=f&&lr(s,o,r,l,a,c,x.x,x.y)&&Ie(x.prev,x,x.next)>=0)return!1;x=x.next}return!0}function Qp(n,t,e,i){let s=n.prev,r=n,a=n.next;if(Ie(s,r,a)>=0)return!1;let o=s.x,l=r.x,c=a.x,h=s.y,d=r.y,u=a.y,f=o<l?o<c?o:c:l<c?l:c,x=h<d?h<u?h:u:d<u?d:u,M=o>l?o>c?o:c:l>c?l:c,m=h>d?h>u?h:u:d>u?d:u,p=qc(f,x,t,e,i),S=qc(M,m,t,e,i),E=n.prevZ,g=n.nextZ;for(;E&&E.z>=p&&g&&g.z<=S;){if(E.x>=f&&E.x<=M&&E.y>=x&&E.y<=m&&E!==s&&E!==a&&lr(o,h,l,d,c,u,E.x,E.y)&&Ie(E.prev,E,E.next)>=0||(E=E.prevZ,g.x>=f&&g.x<=M&&g.y>=x&&g.y<=m&&g!==s&&g!==a&&lr(o,h,l,d,c,u,g.x,g.y)&&Ie(g.prev,g,g.next)>=0))return!1;g=g.nextZ}for(;E&&E.z>=p;){if(E.x>=f&&E.x<=M&&E.y>=x&&E.y<=m&&E!==s&&E!==a&&lr(o,h,l,d,c,u,E.x,E.y)&&Ie(E.prev,E,E.next)>=0)return!1;E=E.prevZ}for(;g&&g.z<=S;){if(g.x>=f&&g.x<=M&&g.y>=x&&g.y<=m&&g!==s&&g!==a&&lr(o,h,l,d,c,u,g.x,g.y)&&Ie(g.prev,g,g.next)>=0)return!1;g=g.nextZ}return!0}function jp(n,t,e){let i=n;do{let s=i.prev,r=i.next.next;!Wl(s,r)&&Gd(s,i,i.next,r)&&fo(s,r)&&fo(r,s)&&(t.push(s.i/e|0),t.push(i.i/e|0),t.push(r.i/e|0),po(i),po(i.next),i=n=r),i=i.next}while(i!==n);return Ps(i)}function tm(n,t,e,i,s,r){let a=n;do{let o=a.next.next;for(;o!==a.prev;){if(a.i!==o.i&&cm(a,o)){let l=Vd(a,o);a=Ps(a,a.next),l=Ps(l,l.next),uo(a,t,e,i,s,r,0),uo(l,t,e,i,s,r,0);return}o=o.next}a=a.next}while(a!==n)}function em(n,t,e,i){let s=[],r,a,o,l,c;for(r=0,a=t.length;r<a;r++)o=t[r]*i,l=r<a-1?t[r+1]*i:n.length,c=zd(n,o,l,i,!1),c===c.next&&(c.steiner=!0),s.push(lm(c));for(s.sort(nm),r=0;r<s.length;r++)e=im(s[r],e);return e}function nm(n,t){return n.x-t.x}function im(n,t){let e=sm(n,t);if(!e)return t;let i=Vd(e,n);return Ps(i,i.next),Ps(e,e.next)}function sm(n,t){let e=t,i=-1/0,s,r=n.x,a=n.y;do{if(a<=e.y&&a>=e.next.y&&e.next.y!==e.y){let u=e.x+(a-e.y)*(e.next.x-e.x)/(e.next.y-e.y);if(u<=r&&u>i&&(i=u,s=e.x<e.next.x?e:e.next,u===r))return s}e=e.next}while(e!==t);if(!s)return null;let o=s,l=s.x,c=s.y,h=1/0,d;e=s;do r>=e.x&&e.x>=l&&r!==e.x&&lr(a<c?r:i,a,l,c,a<c?i:r,a,e.x,e.y)&&(d=Math.abs(a-e.y)/(r-e.x),fo(e,n)&&(d<h||d===h&&(e.x>s.x||e.x===s.x&&rm(s,e)))&&(s=e,h=d)),e=e.next;while(e!==o);return s}function rm(n,t){return Ie(n.prev,n,t.prev)<0&&Ie(t.next,n,n.next)<0}function om(n,t,e,i){let s=n;do s.z===0&&(s.z=qc(s.x,s.y,t,e,i)),s.prevZ=s.prev,s.nextZ=s.next,s=s.next;while(s!==n);s.prevZ.nextZ=null,s.prevZ=null,am(s)}function am(n){let t,e,i,s,r,a,o,l,c=1;do{for(e=n,n=null,r=null,a=0;e;){for(a++,i=e,o=0,t=0;t<c&&(o++,i=i.nextZ,!!i);t++);for(l=c;o>0||l>0&&i;)o!==0&&(l===0||!i||e.z<=i.z)?(s=e,e=e.nextZ,o--):(s=i,i=i.nextZ,l--),r?r.nextZ=s:n=s,s.prevZ=r,r=s;e=i}r.nextZ=null,c*=2}while(a>1);return n}function qc(n,t,e,i,s){return n=(n-e)*s|0,t=(t-i)*s|0,n=(n|n<<8)&16711935,n=(n|n<<4)&252645135,n=(n|n<<2)&858993459,n=(n|n<<1)&1431655765,t=(t|t<<8)&16711935,t=(t|t<<4)&252645135,t=(t|t<<2)&858993459,t=(t|t<<1)&1431655765,n|t<<1}function lm(n){let t=n,e=n;do(t.x<e.x||t.x===e.x&&t.y<e.y)&&(e=t),t=t.next;while(t!==n);return e}function lr(n,t,e,i,s,r,a,o){return(s-a)*(t-o)>=(n-a)*(r-o)&&(n-a)*(i-o)>=(e-a)*(t-o)&&(e-a)*(r-o)>=(s-a)*(i-o)}function cm(n,t){return n.next.i!==t.i&&n.prev.i!==t.i&&!hm(n,t)&&(fo(n,t)&&fo(t,n)&&um(n,t)&&(Ie(n.prev,n,t.prev)||Ie(n,t.prev,t))||Wl(n,t)&&Ie(n.prev,n,n.next)>0&&Ie(t.prev,t,t.next)>0)}function Ie(n,t,e){return(t.y-n.y)*(e.x-t.x)-(t.x-n.x)*(e.y-t.y)}function Wl(n,t){return n.x===t.x&&n.y===t.y}function Gd(n,t,e,i){let s=va(Ie(n,t,e)),r=va(Ie(n,t,i)),a=va(Ie(e,i,n)),o=va(Ie(e,i,t));return!!(s!==r&&a!==o||s===0&&_a(n,e,t)||r===0&&_a(n,i,t)||a===0&&_a(e,n,i)||o===0&&_a(e,t,i))}function _a(n,t,e){return t.x<=Math.max(n.x,e.x)&&t.x>=Math.min(n.x,e.x)&&t.y<=Math.max(n.y,e.y)&&t.y>=Math.min(n.y,e.y)}function va(n){return n>0?1:n<0?-1:0}function hm(n,t){let e=n;do{if(e.i!==n.i&&e.next.i!==n.i&&e.i!==t.i&&e.next.i!==t.i&&Gd(e,e.next,n,t))return!0;e=e.next}while(e!==n);return!1}function fo(n,t){return Ie(n.prev,n,n.next)<0?Ie(n,t,n.next)>=0&&Ie(n,n.prev,t)>=0:Ie(n,t,n.prev)<0||Ie(n,n.next,t)<0}function um(n,t){let e=n,i=!1,s=(n.x+t.x)/2,r=(n.y+t.y)/2;do e.y>r!=e.next.y>r&&e.next.y!==e.y&&s<(e.next.x-e.x)*(r-e.y)/(e.next.y-e.y)+e.x&&(i=!i),e=e.next;while(e!==n);return i}function Vd(n,t){let e=new Yc(n.i,n.x,n.y),i=new Yc(t.i,t.x,t.y),s=n.next,r=t.prev;return n.next=t,t.prev=n,e.next=s,s.prev=e,i.next=e,e.prev=i,r.next=i,i.prev=r,i}function Xu(n,t,e,i){let s=new Yc(n,t,e);return i?(s.next=i.next,s.prev=i,i.next.prev=s,i.next=s):(s.prev=s,s.next=s),s}function po(n){n.next.prev=n.prev,n.prev.next=n.next,n.prevZ&&(n.prevZ.nextZ=n.nextZ),n.nextZ&&(n.nextZ.prevZ=n.prevZ)}function Yc(n,t,e){this.i=n,this.x=t,this.y=e,this.prev=null,this.next=null,this.z=0,this.prevZ=null,this.nextZ=null,this.steiner=!1}function dm(n,t,e,i){let s=0;for(let r=t,a=e-i;r<e;r+=i)s+=(n[a]-n[r])*(n[r+1]+n[a+1]),a=r;return s}var Ei=class n{static area(t){let e=t.length,i=0;for(let s=e-1,r=0;r<e;s=r++)i+=t[s].x*t[r].y-t[r].x*t[s].y;return i*.5}static isClockWise(t){return n.area(t)<0}static triangulateShape(t,e){let i=[],s=[],r=[];qu(t),Yu(i,t);let a=t.length;e.forEach(qu);for(let l=0;l<e.length;l++)s.push(a),a+=e[l].length,Yu(i,e[l]);let o=Jp.triangulate(i,s);for(let l=0;l<o.length;l+=3)r.push(o.slice(l,l+3));return r}};function qu(n){let t=n.length;t>2&&n[t-1].equals(n[0])&&n.pop()}function Yu(n,t){for(let e=0;e<t.length;e++)n.push(t[e].x),n.push(t[e].y)}var si=class n extends qe{constructor(t=new ln([new at(.5,.5),new at(-.5,.5),new at(-.5,-.5),new at(.5,-.5)]),e={}){super(),this.type="ExtrudeGeometry",this.parameters={shapes:t,options:e},t=Array.isArray(t)?t:[t];let i=this,s=[],r=[];for(let o=0,l=t.length;o<l;o++){let c=t[o];a(c)}this.setAttribute("position",new se(s,3)),this.setAttribute("uv",new se(r,2)),this.computeVertexNormals();function a(o){let l=[],c=e.curveSegments!==void 0?e.curveSegments:12,h=e.steps!==void 0?e.steps:1,d=e.depth!==void 0?e.depth:1,u=e.bevelEnabled!==void 0?e.bevelEnabled:!0,f=e.bevelThickness!==void 0?e.bevelThickness:.2,x=e.bevelSize!==void 0?e.bevelSize:f-.1,M=e.bevelOffset!==void 0?e.bevelOffset:0,m=e.bevelSegments!==void 0?e.bevelSegments:3,p=e.extrudePath,S=e.UVGenerator!==void 0?e.UVGenerator:fm,E,g=!1,C,A,_,T;p&&(E=p.getSpacedPoints(h),g=!0,u=!1,C=p.computeFrenetFrames(h,!1),A=new O,_=new O,T=new O),u||(m=0,f=0,x=0,M=0);let v=o.extractPoints(c),y=v.shape,w=v.holes;if(!Ei.isClockWise(y)){y=y.reverse();for(let Q=0,ht=w.length;Q<ht;Q++){let L=w[Q];Ei.isClockWise(L)&&(w[Q]=L.reverse())}}let D=Ei.triangulateShape(y,w),N=y;for(let Q=0,ht=w.length;Q<ht;Q++){let L=w[Q];y=y.concat(L)}function H(Q,ht,L){return ht||console.error("THREE.ExtrudeGeometry: vec does not exist"),Q.clone().addScaledVector(ht,L)}let U=y.length,k=D.length;function F(Q,ht,L){let Nt,pt,At,xt=Q.x-ht.x,Wt=Q.y-ht.y,wt=L.x-Q.x,I=L.y-Q.y,b=xt*xt+Wt*Wt,Y=xt*I-Wt*wt;if(Math.abs(Y)>Number.EPSILON){let it=Math.sqrt(b),ut=Math.sqrt(wt*wt+I*I),st=ht.x-Wt/it,Ut=ht.y+xt/it,vt=L.x-I/ut,bt=L.y+wt/ut,ce=((vt-st)*I-(bt-Ut)*wt)/(xt*I-Wt*wt);Nt=st+xt*ce-Q.x,pt=Ut+Wt*ce-Q.y;let gt=Nt*Nt+pt*pt;if(gt<=2)return new at(Nt,pt);At=Math.sqrt(gt/2)}else{let it=!1;xt>Number.EPSILON?wt>Number.EPSILON&&(it=!0):xt<-Number.EPSILON?wt<-Number.EPSILON&&(it=!0):Math.sign(Wt)===Math.sign(I)&&(it=!0),it?(Nt=-Wt,pt=xt,At=Math.sqrt(b)):(Nt=xt,pt=Wt,At=Math.sqrt(b/2))}return new at(Nt/At,pt/At)}let G=[];for(let Q=0,ht=N.length,L=ht-1,Nt=Q+1;Q<ht;Q++,L++,Nt++)L===ht&&(L=0),Nt===ht&&(Nt=0),G[Q]=F(N[Q],N[L],N[Nt]);let q=[],et,nt=G.concat();for(let Q=0,ht=w.length;Q<ht;Q++){let L=w[Q];et=[];for(let Nt=0,pt=L.length,At=pt-1,xt=Nt+1;Nt<pt;Nt++,At++,xt++)At===pt&&(At=0),xt===pt&&(xt=0),et[Nt]=F(L[Nt],L[At],L[xt]);q.push(et),nt=nt.concat(et)}for(let Q=0;Q<m;Q++){let ht=Q/m,L=f*Math.cos(ht*Math.PI/2),Nt=x*Math.sin(ht*Math.PI/2)+M;for(let pt=0,At=N.length;pt<At;pt++){let xt=H(N[pt],G[pt],Nt);z(xt.x,xt.y,-L)}for(let pt=0,At=w.length;pt<At;pt++){let xt=w[pt];et=q[pt];for(let Wt=0,wt=xt.length;Wt<wt;Wt++){let I=H(xt[Wt],et[Wt],Nt);z(I.x,I.y,-L)}}}let rt=x+M;for(let Q=0;Q<U;Q++){let ht=u?H(y[Q],nt[Q],rt):y[Q];g?(_.copy(C.normals[0]).multiplyScalar(ht.x),A.copy(C.binormals[0]).multiplyScalar(ht.y),T.copy(E[0]).add(_).add(A),z(T.x,T.y,T.z)):z(ht.x,ht.y,0)}for(let Q=1;Q<=h;Q++)for(let ht=0;ht<U;ht++){let L=u?H(y[ht],nt[ht],rt):y[ht];g?(_.copy(C.normals[Q]).multiplyScalar(L.x),A.copy(C.binormals[Q]).multiplyScalar(L.y),T.copy(E[Q]).add(_).add(A),z(T.x,T.y,T.z)):z(L.x,L.y,d/h*Q)}for(let Q=m-1;Q>=0;Q--){let ht=Q/m,L=f*Math.cos(ht*Math.PI/2),Nt=x*Math.sin(ht*Math.PI/2)+M;for(let pt=0,At=N.length;pt<At;pt++){let xt=H(N[pt],G[pt],Nt);z(xt.x,xt.y,d+L)}for(let pt=0,At=w.length;pt<At;pt++){let xt=w[pt];et=q[pt];for(let Wt=0,wt=xt.length;Wt<wt;Wt++){let I=H(xt[Wt],et[Wt],Nt);g?z(I.x,I.y+E[h-1].y,E[h-1].x+L):z(I.x,I.y,d+L)}}}B(),Z();function B(){let Q=s.length/3;if(u){let ht=0,L=U*ht;for(let Nt=0;Nt<k;Nt++){let pt=D[Nt];j(pt[2]+L,pt[1]+L,pt[0]+L)}ht=h+m*2,L=U*ht;for(let Nt=0;Nt<k;Nt++){let pt=D[Nt];j(pt[0]+L,pt[1]+L,pt[2]+L)}}else{for(let ht=0;ht<k;ht++){let L=D[ht];j(L[2],L[1],L[0])}for(let ht=0;ht<k;ht++){let L=D[ht];j(L[0]+U*h,L[1]+U*h,L[2]+U*h)}}i.addGroup(Q,s.length/3-Q,0)}function Z(){let Q=s.length/3,ht=0;ct(N,ht),ht+=N.length;for(let L=0,Nt=w.length;L<Nt;L++){let pt=w[L];ct(pt,ht),ht+=pt.length}i.addGroup(Q,s.length/3-Q,1)}function ct(Q,ht){let L=Q.length;for(;--L>=0;){let Nt=L,pt=L-1;pt<0&&(pt=Q.length-1);for(let At=0,xt=h+m*2;At<xt;At++){let Wt=U*At,wt=U*(At+1),I=ht+Nt+Wt,b=ht+pt+Wt,Y=ht+pt+wt,it=ht+Nt+wt;ft(I,b,Y,it)}}}function z(Q,ht,L){l.push(Q),l.push(ht),l.push(L)}function j(Q,ht,L){dt(Q),dt(ht),dt(L);let Nt=s.length/3,pt=S.generateTopUV(i,s,Nt-3,Nt-2,Nt-1);Ct(pt[0]),Ct(pt[1]),Ct(pt[2])}function ft(Q,ht,L,Nt){dt(Q),dt(ht),dt(Nt),dt(ht),dt(L),dt(Nt);let pt=s.length/3,At=S.generateSideWallUV(i,s,pt-6,pt-3,pt-2,pt-1);Ct(At[0]),Ct(At[1]),Ct(At[3]),Ct(At[1]),Ct(At[2]),Ct(At[3])}function dt(Q){s.push(l[Q*3+0]),s.push(l[Q*3+1]),s.push(l[Q*3+2])}function Ct(Q){r.push(Q.x),r.push(Q.y)}}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON(),e=this.parameters.shapes,i=this.parameters.options;return pm(e,i,t)}static fromJSON(t,e){let i=[];for(let r=0,a=t.shapes.length;r<a;r++){let o=e[t.shapes[r]];i.push(o)}let s=t.options.extrudePath;return s!==void 0&&(t.options.extrudePath=new Oa[s.type]().fromJSON(s)),new n(i,t.options)}},fm={generateTopUV:function(n,t,e,i,s){let r=t[e*3],a=t[e*3+1],o=t[i*3],l=t[i*3+1],c=t[s*3],h=t[s*3+1];return[new at(r,a),new at(o,l),new at(c,h)]},generateSideWallUV:function(n,t,e,i,s,r){let a=t[e*3],o=t[e*3+1],l=t[e*3+2],c=t[i*3],h=t[i*3+1],d=t[i*3+2],u=t[s*3],f=t[s*3+1],x=t[s*3+2],M=t[r*3],m=t[r*3+1],p=t[r*3+2];return Math.abs(o-h)<Math.abs(a-c)?[new at(a,1-l),new at(c,1-d),new at(u,1-x),new at(M,1-p)]:[new at(o,1-l),new at(h,1-d),new at(f,1-x),new at(m,1-p)]}};function pm(n,t,e){if(e.shapes=[],Array.isArray(n))for(let i=0,s=n.length;i<s;i++){let r=n[i];e.shapes.push(r.uuid)}else e.shapes.push(n.uuid);return e.options=Object.assign({},t),t.extrudePath!==void 0&&(e.options.extrudePath=t.extrudePath.toJSON()),e}var Ai=class n extends ho{constructor(t=1,e=0){let i=(1+Math.sqrt(5))/2,s=[-1,i,0,1,i,0,-1,-i,0,1,-i,0,0,-1,i,0,1,i,0,-1,-i,0,1,-i,i,0,-1,i,0,1,-i,0,-1,-i,0,1],r=[0,11,5,0,5,1,0,1,7,0,7,10,0,10,11,1,5,9,5,11,4,11,10,2,10,7,6,7,1,8,3,9,4,3,4,2,3,2,6,3,6,8,3,8,9,4,9,5,2,4,11,6,2,10,8,6,7,9,8,1];super(s,r,t,e),this.type="IcosahedronGeometry",this.parameters={radius:t,detail:e}}static fromJSON(t){return new n(t.radius,t.detail)}};var we=class n extends qe{constructor(t=1,e=1,i=1,s=1){super(),this.type="PlaneGeometry",this.parameters={width:t,height:e,widthSegments:i,heightSegments:s};let r=t/2,a=e/2,o=Math.floor(i),l=Math.floor(s),c=o+1,h=l+1,d=t/o,u=e/l,f=[],x=[],M=[],m=[];for(let p=0;p<h;p++){let S=p*u-a;for(let E=0;E<c;E++){let g=E*d-r;x.push(g,-S,0),M.push(0,0,1),m.push(E/o),m.push(1-p/l)}}for(let p=0;p<l;p++)for(let S=0;S<o;S++){let E=S+c*p,g=S+c*(p+1),C=S+1+c*(p+1),A=S+1+c*p;f.push(E,g,A),f.push(g,C,A)}this.setIndex(f),this.setAttribute("position",new se(x,3)),this.setAttribute("normal",new se(M,3)),this.setAttribute("uv",new se(m,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.width,t.height,t.widthSegments,t.heightSegments)}},gr=class n extends qe{constructor(t=.5,e=1,i=32,s=1,r=0,a=Math.PI*2){super(),this.type="RingGeometry",this.parameters={innerRadius:t,outerRadius:e,thetaSegments:i,phiSegments:s,thetaStart:r,thetaLength:a},i=Math.max(3,i),s=Math.max(1,s);let o=[],l=[],c=[],h=[],d=t,u=(e-t)/s,f=new O,x=new at;for(let M=0;M<=s;M++){for(let m=0;m<=i;m++){let p=r+m/i*a;f.x=d*Math.cos(p),f.y=d*Math.sin(p),l.push(f.x,f.y,f.z),c.push(0,0,1),x.x=(f.x/e+1)/2,x.y=(f.y/e+1)/2,h.push(x.x,x.y)}d+=u}for(let M=0;M<s;M++){let m=M*(i+1);for(let p=0;p<i;p++){let S=p+m,E=S,g=S+i+1,C=S+i+2,A=S+1;o.push(E,g,A),o.push(g,C,A)}}this.setIndex(o),this.setAttribute("position",new se(l,3)),this.setAttribute("normal",new se(c,3)),this.setAttribute("uv",new se(h,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.innerRadius,t.outerRadius,t.thetaSegments,t.phiSegments,t.thetaStart,t.thetaLength)}},ts=class n extends qe{constructor(t=new ln([new at(0,.5),new at(-.5,-.5),new at(.5,-.5)]),e=12){super(),this.type="ShapeGeometry",this.parameters={shapes:t,curveSegments:e};let i=[],s=[],r=[],a=[],o=0,l=0;if(Array.isArray(t)===!1)c(t);else for(let h=0;h<t.length;h++)c(t[h]),this.addGroup(o,l,h),o+=l,l=0;this.setIndex(i),this.setAttribute("position",new se(s,3)),this.setAttribute("normal",new se(r,3)),this.setAttribute("uv",new se(a,2));function c(h){let d=s.length/3,u=h.extractPoints(e),f=u.shape,x=u.holes;Ei.isClockWise(f)===!1&&(f=f.reverse());for(let m=0,p=x.length;m<p;m++){let S=x[m];Ei.isClockWise(S)===!0&&(x[m]=S.reverse())}let M=Ei.triangulateShape(f,x);for(let m=0,p=x.length;m<p;m++){let S=x[m];f=f.concat(S)}for(let m=0,p=f.length;m<p;m++){let S=f[m];s.push(S.x,S.y,0),r.push(0,0,1),a.push(S.x,S.y)}for(let m=0,p=M.length;m<p;m++){let S=M[m],E=S[0]+d,g=S[1]+d,C=S[2]+d;i.push(E,g,C),l+=3}}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON(),e=this.parameters.shapes;return mm(e,t)}static fromJSON(t,e){let i=[];for(let s=0,r=t.shapes.length;s<r;s++){let a=e[t.shapes[s]];i.push(a)}return new n(i,t.curveSegments)}};function mm(n,t){if(t.shapes=[],Array.isArray(n))for(let e=0,i=n.length;e<i;e++){let s=n[e];t.shapes.push(s.uuid)}else t.shapes.push(n.uuid);return t}var ye=class n extends qe{constructor(t=1,e=32,i=16,s=0,r=Math.PI*2,a=0,o=Math.PI){super(),this.type="SphereGeometry",this.parameters={radius:t,widthSegments:e,heightSegments:i,phiStart:s,phiLength:r,thetaStart:a,thetaLength:o},e=Math.max(3,Math.floor(e)),i=Math.max(2,Math.floor(i));let l=Math.min(a+o,Math.PI),c=0,h=[],d=new O,u=new O,f=[],x=[],M=[],m=[];for(let p=0;p<=i;p++){let S=[],E=p/i,g=0;p===0&&a===0?g=.5/e:p===i&&l===Math.PI&&(g=-.5/e);for(let C=0;C<=e;C++){let A=C/e;d.x=-t*Math.cos(s+A*r)*Math.sin(a+E*o),d.y=t*Math.cos(a+E*o),d.z=t*Math.sin(s+A*r)*Math.sin(a+E*o),x.push(d.x,d.y,d.z),u.copy(d).normalize(),M.push(u.x,u.y,u.z),m.push(A+g,1-E),S.push(c++)}h.push(S)}for(let p=0;p<i;p++)for(let S=0;S<e;S++){let E=h[p][S+1],g=h[p][S],C=h[p+1][S],A=h[p+1][S+1];(p!==0||a>0)&&f.push(E,g,A),(p!==i-1||l<Math.PI)&&f.push(g,C,A)}this.setIndex(f),this.setAttribute("position",new se(x,3)),this.setAttribute("normal",new se(M,3)),this.setAttribute("uv",new se(m,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.radius,t.widthSegments,t.heightSegments,t.phiStart,t.phiLength,t.thetaStart,t.thetaLength)}};var _n=class n extends qe{constructor(t=1,e=.4,i=12,s=48,r=Math.PI*2){super(),this.type="TorusGeometry",this.parameters={radius:t,tube:e,radialSegments:i,tubularSegments:s,arc:r},i=Math.floor(i),s=Math.floor(s);let a=[],o=[],l=[],c=[],h=new O,d=new O,u=new O;for(let f=0;f<=i;f++)for(let x=0;x<=s;x++){let M=x/s*r,m=f/i*Math.PI*2;d.x=(t+e*Math.cos(m))*Math.cos(M),d.y=(t+e*Math.cos(m))*Math.sin(M),d.z=e*Math.sin(m),o.push(d.x,d.y,d.z),h.x=t*Math.cos(M),h.y=t*Math.sin(M),u.subVectors(d,h).normalize(),l.push(u.x,u.y,u.z),c.push(x/s),c.push(f/i)}for(let f=1;f<=i;f++)for(let x=1;x<=s;x++){let M=(s+1)*f+x-1,m=(s+1)*(f-1)+x-1,p=(s+1)*(f-1)+x,S=(s+1)*f+x;a.push(M,m,S),a.push(m,p,S)}this.setIndex(a),this.setAttribute("position",new se(o,3)),this.setAttribute("normal",new se(l,3)),this.setAttribute("uv",new se(c,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new n(t.radius,t.tube,t.radialSegments,t.tubularSegments,t.arc)}};var mo=class n extends qe{constructor(t=new lo(new O(-1,-1,0),new O(-1,1,0),new O(1,1,0)),e=64,i=1,s=8,r=!1){super(),this.type="TubeGeometry",this.parameters={path:t,tubularSegments:e,radius:i,radialSegments:s,closed:r};let a=t.computeFrenetFrames(e,r);this.tangents=a.tangents,this.normals=a.normals,this.binormals=a.binormals;let o=new O,l=new O,c=new at,h=new O,d=[],u=[],f=[],x=[];M(),this.setIndex(x),this.setAttribute("position",new se(d,3)),this.setAttribute("normal",new se(u,3)),this.setAttribute("uv",new se(f,2));function M(){for(let E=0;E<e;E++)m(E);m(r===!1?e:0),S(),p()}function m(E){h=t.getPointAt(E/e,h);let g=a.normals[E],C=a.binormals[E];for(let A=0;A<=s;A++){let _=A/s*Math.PI*2,T=Math.sin(_),v=-Math.cos(_);l.x=v*g.x+T*C.x,l.y=v*g.y+T*C.y,l.z=v*g.z+T*C.z,l.normalize(),u.push(l.x,l.y,l.z),o.x=h.x+i*l.x,o.y=h.y+i*l.y,o.z=h.z+i*l.z,d.push(o.x,o.y,o.z)}}function p(){for(let E=1;E<=e;E++)for(let g=1;g<=s;g++){let C=(s+1)*(E-1)+(g-1),A=(s+1)*E+(g-1),_=(s+1)*E+g,T=(s+1)*(E-1)+g;x.push(C,A,T),x.push(A,_,T)}}function S(){for(let E=0;E<=e;E++)for(let g=0;g<=s;g++)c.x=E/e,c.y=g/s,f.push(c.x,c.y)}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON();return t.path=this.parameters.path.toJSON(),t}static fromJSON(t){return new n(new Oa[t.path.type]().fromJSON(t.path),t.tubularSegments,t.radius,t.radialSegments,t.closed)}};var Lt=class extends bi{constructor(t){super(),this.isMeshStandardMaterial=!0,this.type="MeshStandardMaterial",this.defines={STANDARD:""},this.color=new Ot(16777215),this.roughness=1,this.metalness=0,this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.emissive=new Ot(0),this.emissiveIntensity=1,this.emissiveMap=null,this.bumpMap=null,this.bumpScale=1,this.normalMap=null,this.normalMapType=Vl,this.normalScale=new at(1,1),this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.roughnessMap=null,this.metalnessMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Ln,this.envMapIntensity=1,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.flatShading=!1,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.defines={STANDARD:""},this.color.copy(t.color),this.roughness=t.roughness,this.metalness=t.metalness,this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.emissive.copy(t.emissive),this.emissiveMap=t.emissiveMap,this.emissiveIntensity=t.emissiveIntensity,this.bumpMap=t.bumpMap,this.bumpScale=t.bumpScale,this.normalMap=t.normalMap,this.normalMapType=t.normalMapType,this.normalScale.copy(t.normalScale),this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.roughnessMap=t.roughnessMap,this.metalnessMap=t.metalnessMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.envMapIntensity=t.envMapIntensity,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.flatShading=t.flatShading,this.fog=t.fog,this}},ri=class extends Lt{constructor(t){super(),this.isMeshPhysicalMaterial=!0,this.defines={STANDARD:"",PHYSICAL:""},this.type="MeshPhysicalMaterial",this.anisotropyRotation=0,this.anisotropyMap=null,this.clearcoatMap=null,this.clearcoatRoughness=0,this.clearcoatRoughnessMap=null,this.clearcoatNormalScale=new at(1,1),this.clearcoatNormalMap=null,this.ior=1.5,Object.defineProperty(this,"reflectivity",{get:function(){return ie(2.5*(this.ior-1)/(this.ior+1),0,1)},set:function(e){this.ior=(1+.4*e)/(1-.4*e)}}),this.iridescenceMap=null,this.iridescenceIOR=1.3,this.iridescenceThicknessRange=[100,400],this.iridescenceThicknessMap=null,this.sheenColor=new Ot(0),this.sheenColorMap=null,this.sheenRoughness=1,this.sheenRoughnessMap=null,this.transmissionMap=null,this.thickness=0,this.thicknessMap=null,this.attenuationDistance=1/0,this.attenuationColor=new Ot(1,1,1),this.specularIntensity=1,this.specularIntensityMap=null,this.specularColor=new Ot(1,1,1),this.specularColorMap=null,this._anisotropy=0,this._clearcoat=0,this._dispersion=0,this._iridescence=0,this._sheen=0,this._transmission=0,this.setValues(t)}get anisotropy(){return this._anisotropy}set anisotropy(t){this._anisotropy>0!=t>0&&this.version++,this._anisotropy=t}get clearcoat(){return this._clearcoat}set clearcoat(t){this._clearcoat>0!=t>0&&this.version++,this._clearcoat=t}get iridescence(){return this._iridescence}set iridescence(t){this._iridescence>0!=t>0&&this.version++,this._iridescence=t}get dispersion(){return this._dispersion}set dispersion(t){this._dispersion>0!=t>0&&this.version++,this._dispersion=t}get sheen(){return this._sheen}set sheen(t){this._sheen>0!=t>0&&this.version++,this._sheen=t}get transmission(){return this._transmission}set transmission(t){this._transmission>0!=t>0&&this.version++,this._transmission=t}copy(t){return super.copy(t),this.defines={STANDARD:"",PHYSICAL:""},this.anisotropy=t.anisotropy,this.anisotropyRotation=t.anisotropyRotation,this.anisotropyMap=t.anisotropyMap,this.clearcoat=t.clearcoat,this.clearcoatMap=t.clearcoatMap,this.clearcoatRoughness=t.clearcoatRoughness,this.clearcoatRoughnessMap=t.clearcoatRoughnessMap,this.clearcoatNormalMap=t.clearcoatNormalMap,this.clearcoatNormalScale.copy(t.clearcoatNormalScale),this.dispersion=t.dispersion,this.ior=t.ior,this.iridescence=t.iridescence,this.iridescenceMap=t.iridescenceMap,this.iridescenceIOR=t.iridescenceIOR,this.iridescenceThicknessRange=[...t.iridescenceThicknessRange],this.iridescenceThicknessMap=t.iridescenceThicknessMap,this.sheen=t.sheen,this.sheenColor.copy(t.sheenColor),this.sheenColorMap=t.sheenColorMap,this.sheenRoughness=t.sheenRoughness,this.sheenRoughnessMap=t.sheenRoughnessMap,this.transmission=t.transmission,this.transmissionMap=t.transmissionMap,this.thickness=t.thickness,this.thicknessMap=t.thicknessMap,this.attenuationDistance=t.attenuationDistance,this.attenuationColor.copy(t.attenuationColor),this.specularIntensity=t.specularIntensity,this.specularIntensityMap=t.specularIntensityMap,this.specularColor.copy(t.specularColor),this.specularColorMap=t.specularColorMap,this}};var xr=class extends bi{constructor(t){super(),this.isMeshLambertMaterial=!0,this.type="MeshLambertMaterial",this.color=new Ot(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.emissive=new Ot(0),this.emissiveIntensity=1,this.emissiveMap=null,this.bumpMap=null,this.bumpScale=1,this.normalMap=null,this.normalMapType=Vl,this.normalScale=new at(1,1),this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Ln,this.combine=rl,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.flatShading=!1,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.emissive.copy(t.emissive),this.emissiveMap=t.emissiveMap,this.emissiveIntensity=t.emissiveIntensity,this.bumpMap=t.bumpMap,this.bumpScale=t.bumpScale,this.normalMap=t.normalMap,this.normalMapType=t.normalMapType,this.normalScale.copy(t.normalScale),this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.specularMap=t.specularMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.combine=t.combine,this.reflectivity=t.reflectivity,this.refractionRatio=t.refractionRatio,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.flatShading=t.flatShading,this.fog=t.fog,this}},Ba=class extends bi{constructor(t){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=Td,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(t)}copy(t){return super.copy(t),this.depthPacking=t.depthPacking,this.map=t.map,this.alphaMap=t.alphaMap,this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this}},ka=class extends bi{constructor(t){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(t)}copy(t){return super.copy(t),this.map=t.map,this.alphaMap=t.alphaMap,this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this}};function Ma(n,t,e){return!n||!e&&n.constructor===t?n:typeof t.BYTES_PER_ELEMENT=="number"?new t(n):Array.prototype.slice.call(n)}function gm(n){return ArrayBuffer.isView(n)&&!(n instanceof DataView)}var Is=class{constructor(t,e,i,s){this.parameterPositions=t,this._cachedIndex=0,this.resultBuffer=s!==void 0?s:new e.constructor(i),this.sampleValues=e,this.valueSize=i,this.settings=null,this.DefaultSettings_={}}evaluate(t){let e=this.parameterPositions,i=this._cachedIndex,s=e[i],r=e[i-1];n:{t:{let a;e:{i:if(!(t<s)){for(let o=i+2;;){if(s===void 0){if(t<r)break i;return i=e.length,this._cachedIndex=i,this.copySampleValue_(i-1)}if(i===o)break;if(r=s,s=e[++i],t<s)break t}a=e.length;break e}if(!(t>=r)){let o=e[1];t<o&&(i=2,r=o);for(let l=i-2;;){if(r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(i===l)break;if(s=r,r=e[--i-1],t>=r)break t}a=i,i=0;break e}break n}for(;i<a;){let o=i+a>>>1;t<e[o]?a=o:i=o+1}if(s=e[i],r=e[i-1],r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(s===void 0)return i=e.length,this._cachedIndex=i,this.copySampleValue_(i-1)}this._cachedIndex=i,this.intervalChanged_(i,r,s)}return this.interpolate_(i,r,t,s)}getSettings_(){return this.settings||this.DefaultSettings_}copySampleValue_(t){let e=this.resultBuffer,i=this.sampleValues,s=this.valueSize,r=t*s;for(let a=0;a!==s;++a)e[a]=i[r+a];return e}interpolate_(){throw new Error("call to abstract method")}intervalChanged_(){}},za=class extends Is{constructor(t,e,i,s){super(t,e,i,s),this._weightPrev=-0,this._offsetPrev=-0,this._weightNext=-0,this._offsetNext=-0,this.DefaultSettings_={endingStart:zc,endingEnd:zc}}intervalChanged_(t,e,i){let s=this.parameterPositions,r=t-2,a=t+1,o=s[r],l=s[a];if(o===void 0)switch(this.getSettings_().endingStart){case Gc:r=t,o=2*e-i;break;case Vc:r=s.length-2,o=e+s[r]-s[r+1];break;default:r=t,o=i}if(l===void 0)switch(this.getSettings_().endingEnd){case Gc:a=t,l=2*i-e;break;case Vc:a=1,l=i+s[1]-s[0];break;default:a=t-1,l=e}let c=(i-e)*.5,h=this.valueSize;this._weightPrev=c/(e-o),this._weightNext=c/(l-i),this._offsetPrev=r*h,this._offsetNext=a*h}interpolate_(t,e,i,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=t*o,c=l-o,h=this._offsetPrev,d=this._offsetNext,u=this._weightPrev,f=this._weightNext,x=(i-e)/(s-e),M=x*x,m=M*x,p=-u*m+2*u*M-u*x,S=(1+u)*m+(-1.5-2*u)*M+(-.5+u)*x+1,E=(-1-f)*m+(1.5+f)*M+.5*x,g=f*m-f*M;for(let C=0;C!==o;++C)r[C]=p*a[h+C]+S*a[c+C]+E*a[l+C]+g*a[d+C];return r}},Ga=class extends Is{constructor(t,e,i,s){super(t,e,i,s)}interpolate_(t,e,i,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=t*o,c=l-o,h=(i-e)/(s-e),d=1-h;for(let u=0;u!==o;++u)r[u]=a[c+u]*d+a[l+u]*h;return r}},Va=class extends Is{constructor(t,e,i,s){super(t,e,i,s)}interpolate_(t){return this.copySampleValue_(t-1)}},Dn=class{constructor(t,e,i,s){if(t===void 0)throw new Error("THREE.KeyframeTrack: track name is undefined");if(e===void 0||e.length===0)throw new Error("THREE.KeyframeTrack: no keyframes in track named "+t);this.name=t,this.times=Ma(e,this.TimeBufferType),this.values=Ma(i,this.ValueBufferType),this.setInterpolation(s||this.DefaultInterpolation)}static toJSON(t){let e=t.constructor,i;if(e.toJSON!==this.toJSON)i=e.toJSON(t);else{i={name:t.name,times:Ma(t.times,Array),values:Ma(t.values,Array)};let s=t.getInterpolation();s!==t.DefaultInterpolation&&(i.interpolation=s)}return i.type=t.ValueTypeName,i}InterpolantFactoryMethodDiscrete(t){return new Va(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodLinear(t){return new Ga(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodSmooth(t){return new za(this.times,this.values,this.getValueSize(),t)}setInterpolation(t){let e;switch(t){case qr:e=this.InterpolantFactoryMethodDiscrete;break;case Ta:e=this.InterpolantFactoryMethodLinear;break;case Ea:e=this.InterpolantFactoryMethodSmooth;break}if(e===void 0){let i="unsupported interpolation for "+this.ValueTypeName+" keyframe track named "+this.name;if(this.createInterpolant===void 0)if(t!==this.DefaultInterpolation)this.setInterpolation(this.DefaultInterpolation);else throw new Error(i);return console.warn("THREE.KeyframeTrack:",i),this}return this.createInterpolant=e,this}getInterpolation(){switch(this.createInterpolant){case this.InterpolantFactoryMethodDiscrete:return qr;case this.InterpolantFactoryMethodLinear:return Ta;case this.InterpolantFactoryMethodSmooth:return Ea}}getValueSize(){return this.values.length/this.times.length}shift(t){if(t!==0){let e=this.times;for(let i=0,s=e.length;i!==s;++i)e[i]+=t}return this}scale(t){if(t!==1){let e=this.times;for(let i=0,s=e.length;i!==s;++i)e[i]*=t}return this}trim(t,e){let i=this.times,s=i.length,r=0,a=s-1;for(;r!==s&&i[r]<t;)++r;for(;a!==-1&&i[a]>e;)--a;if(++a,r!==0||a!==s){r>=a&&(a=Math.max(a,1),r=a-1);let o=this.getValueSize();this.times=i.slice(r,a),this.values=this.values.slice(r*o,a*o)}return this}validate(){let t=!0,e=this.getValueSize();e-Math.floor(e)!==0&&(console.error("THREE.KeyframeTrack: Invalid value size in track.",this),t=!1);let i=this.times,s=this.values,r=i.length;r===0&&(console.error("THREE.KeyframeTrack: Track is empty.",this),t=!1);let a=null;for(let o=0;o!==r;o++){let l=i[o];if(typeof l=="number"&&isNaN(l)){console.error("THREE.KeyframeTrack: Time is not a valid number.",this,o,l),t=!1;break}if(a!==null&&a>l){console.error("THREE.KeyframeTrack: Out of order keys.",this,o,l,a),t=!1;break}a=l}if(s!==void 0&&gm(s))for(let o=0,l=s.length;o!==l;++o){let c=s[o];if(isNaN(c)){console.error("THREE.KeyframeTrack: Value is not a valid number.",this,o,c),t=!1;break}}return t}optimize(){let t=this.times.slice(),e=this.values.slice(),i=this.getValueSize(),s=this.getInterpolation()===Ea,r=t.length-1,a=1;for(let o=1;o<r;++o){let l=!1,c=t[o],h=t[o+1];if(c!==h&&(o!==1||c!==t[0]))if(s)l=!0;else{let d=o*i,u=d-i,f=d+i;for(let x=0;x!==i;++x){let M=e[d+x];if(M!==e[u+x]||M!==e[f+x]){l=!0;break}}}if(l){if(o!==a){t[a]=t[o];let d=o*i,u=a*i;for(let f=0;f!==i;++f)e[u+f]=e[d+f]}++a}}if(r>0){t[a]=t[r];for(let o=r*i,l=a*i,c=0;c!==i;++c)e[l+c]=e[o+c];++a}return a!==t.length?(this.times=t.slice(0,a),this.values=e.slice(0,a*i)):(this.times=t,this.values=e),this}clone(){let t=this.times.slice(),e=this.values.slice(),i=this.constructor,s=new i(this.name,t,e);return s.createInterpolant=this.createInterpolant,s}};Dn.prototype.TimeBufferType=Float32Array;Dn.prototype.ValueBufferType=Float32Array;Dn.prototype.DefaultInterpolation=Ta;var es=class extends Dn{constructor(t,e,i){super(t,e,i)}};es.prototype.ValueTypeName="bool";es.prototype.ValueBufferType=Array;es.prototype.DefaultInterpolation=qr;es.prototype.InterpolantFactoryMethodLinear=void 0;es.prototype.InterpolantFactoryMethodSmooth=void 0;var Wa=class extends Dn{};Wa.prototype.ValueTypeName="color";var Xa=class extends Dn{};Xa.prototype.ValueTypeName="number";var qa=class extends Is{constructor(t,e,i,s){super(t,e,i,s)}interpolate_(t,e,i,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=(i-e)/(s-e),c=t*o;for(let h=c+o;c!==h;c+=4)Ti.slerpFlat(r,0,a,c-o,a,c,l);return r}},go=class extends Dn{InterpolantFactoryMethodLinear(t){return new qa(this.times,this.values,this.getValueSize(),t)}};go.prototype.ValueTypeName="quaternion";go.prototype.InterpolantFactoryMethodSmooth=void 0;var ns=class extends Dn{constructor(t,e,i){super(t,e,i)}};ns.prototype.ValueTypeName="string";ns.prototype.ValueBufferType=Array;ns.prototype.DefaultInterpolation=qr;ns.prototype.InterpolantFactoryMethodLinear=void 0;ns.prototype.InterpolantFactoryMethodSmooth=void 0;var Ya=class extends Dn{};Ya.prototype.ValueTypeName="vector";var $c={enabled:!1,files:{},add:function(n,t){this.enabled!==!1&&(this.files[n]=t)},get:function(n){if(this.enabled!==!1)return this.files[n]},remove:function(n){delete this.files[n]},clear:function(){this.files={}}},$a=class{constructor(t,e,i){let s=this,r=!1,a=0,o=0,l,c=[];this.onStart=void 0,this.onLoad=t,this.onProgress=e,this.onError=i,this.itemStart=function(h){o++,r===!1&&s.onStart!==void 0&&s.onStart(h,a,o),r=!0},this.itemEnd=function(h){a++,s.onProgress!==void 0&&s.onProgress(h,a,o),a===o&&(r=!1,s.onLoad!==void 0&&s.onLoad())},this.itemError=function(h){s.onError!==void 0&&s.onError(h)},this.resolveURL=function(h){return l?l(h):h},this.setURLModifier=function(h){return l=h,this},this.addHandler=function(h,d){return c.push(h,d),this},this.removeHandler=function(h){let d=c.indexOf(h);return d!==-1&&c.splice(d,2),this},this.getHandler=function(h){for(let d=0,u=c.length;d<u;d+=2){let f=c[d],x=c[d+1];if(f.global&&(f.lastIndex=0),f.test(h))return x}return null}}},Wd=new $a,yr=class{constructor(t){this.manager=t!==void 0?t:Wd,this.crossOrigin="anonymous",this.withCredentials=!1,this.path="",this.resourcePath="",this.requestHeader={}}load(){}loadAsync(t,e){let i=this;return new Promise(function(s,r){i.load(t,s,e,r)})}parse(){}setCrossOrigin(t){return this.crossOrigin=t,this}setWithCredentials(t){return this.withCredentials=t,this}setPath(t){return this.path=t,this}setResourcePath(t){return this.resourcePath=t,this}setRequestHeader(t){return this.requestHeader=t,this}};yr.DEFAULT_MATERIAL_NAME="__DEFAULT";var Za=class extends yr{constructor(t){super(t)}load(t,e,i,s){this.path!==void 0&&(t=this.path+t),t=this.manager.resolveURL(t);let r=this,a=$c.get(t);if(a!==void 0)return r.manager.itemStart(t),setTimeout(function(){e&&e(a),r.manager.itemEnd(t)},0),a;let o=ur("img");function l(){h(),$c.add(t,this),e&&e(this),r.manager.itemEnd(t)}function c(d){h(),s&&s(d),r.manager.itemError(t),r.manager.itemEnd(t)}function h(){o.removeEventListener("load",l,!1),o.removeEventListener("error",c,!1)}return o.addEventListener("load",l,!1),o.addEventListener("error",c,!1),t.slice(0,5)!=="data:"&&this.crossOrigin!==void 0&&(o.crossOrigin=this.crossOrigin),r.manager.itemStart(t),o.src=t,o}};var xo=class extends yr{constructor(t){super(t)}load(t,e,i,s){let r=new an,a=new Za(this.manager);return a.setCrossOrigin(this.crossOrigin),a.setPath(this.path),a.load(t,function(o){r.image=o,r.needsUpdate=!0,e!==void 0&&e(r)},i,s),r}},yo=class extends Oe{constructor(t,e=1){super(),this.isLight=!0,this.type="Light",this.color=new Ot(t),this.intensity=e}dispose(){}copy(t,e){return super.copy(t,e),this.color.copy(t.color),this.intensity=t.intensity,this}toJSON(t){let e=super.toJSON(t);return e.object.color=this.color.getHex(),e.object.intensity=this.intensity,this.groundColor!==void 0&&(e.object.groundColor=this.groundColor.getHex()),this.distance!==void 0&&(e.object.distance=this.distance),this.angle!==void 0&&(e.object.angle=this.angle),this.decay!==void 0&&(e.object.decay=this.decay),this.penumbra!==void 0&&(e.object.penumbra=this.penumbra),this.shadow!==void 0&&(e.object.shadow=this.shadow.toJSON()),this.target!==void 0&&(e.object.target=this.target.uuid),e}},_o=class extends yo{constructor(t,e,i){super(t,i),this.isHemisphereLight=!0,this.type="HemisphereLight",this.position.copy(Oe.DEFAULT_UP),this.updateMatrix(),this.groundColor=new Ot(e)}copy(t,e){return super.copy(t,e),this.groundColor.copy(t.groundColor),this}},kc=new be,$u=new O,Zu=new O,Zc=class{constructor(t){this.camera=t,this.intensity=1,this.bias=0,this.normalBias=0,this.radius=1,this.blurSamples=8,this.mapSize=new at(512,512),this.map=null,this.mapPass=null,this.matrix=new be,this.autoUpdate=!0,this.needsUpdate=!1,this._frustum=new fr,this._frameExtents=new at(1,1),this._viewportCount=1,this._viewports=[new Le(0,0,1,1)]}getViewportCount(){return this._viewportCount}getFrustum(){return this._frustum}updateMatrices(t){let e=this.camera,i=this.matrix;$u.setFromMatrixPosition(t.matrixWorld),e.position.copy($u),Zu.setFromMatrixPosition(t.target.matrixWorld),e.lookAt(Zu),e.updateMatrixWorld(),kc.multiplyMatrices(e.projectionMatrix,e.matrixWorldInverse),this._frustum.setFromProjectionMatrix(kc),i.set(.5,0,0,.5,0,.5,0,.5,0,0,.5,.5,0,0,0,1),i.multiply(kc)}getViewport(t){return this._viewports[t]}getFrameExtents(){return this._frameExtents}dispose(){this.map&&this.map.dispose(),this.mapPass&&this.mapPass.dispose()}copy(t){return this.camera=t.camera.clone(),this.intensity=t.intensity,this.bias=t.bias,this.radius=t.radius,this.mapSize.copy(t.mapSize),this}clone(){return new this.constructor().copy(this)}toJSON(){let t={};return this.intensity!==1&&(t.intensity=this.intensity),this.bias!==0&&(t.bias=this.bias),this.normalBias!==0&&(t.normalBias=this.normalBias),this.radius!==1&&(t.radius=this.radius),(this.mapSize.x!==512||this.mapSize.y!==512)&&(t.mapSize=this.mapSize.toArray()),t.camera=this.camera.toJSON(!1).object,delete t.camera.matrix,t}};var vo=class extends to{constructor(t=-1,e=1,i=1,s=-1,r=.1,a=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=t,this.right=e,this.top=i,this.bottom=s,this.near=r,this.far=a,this.updateProjectionMatrix()}copy(t,e){return super.copy(t,e),this.left=t.left,this.right=t.right,this.top=t.top,this.bottom=t.bottom,this.near=t.near,this.far=t.far,this.zoom=t.zoom,this.view=t.view===null?null:Object.assign({},t.view),this}setViewOffset(t,e,i,s,r,a){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=t,this.view.fullHeight=e,this.view.offsetX=i,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let t=(this.right-this.left)/(2*this.zoom),e=(this.top-this.bottom)/(2*this.zoom),i=(this.right+this.left)/2,s=(this.top+this.bottom)/2,r=i-t,a=i+t,o=s+e,l=s-e;if(this.view!==null&&this.view.enabled){let c=(this.right-this.left)/this.view.fullWidth/this.zoom,h=(this.top-this.bottom)/this.view.fullHeight/this.zoom;r+=c*this.view.offsetX,a=r+c*this.view.width,o-=h*this.view.offsetY,l=o-h*this.view.height}this.projectionMatrix.makeOrthographic(r,a,o,l,this.near,this.far,this.coordinateSystem),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(t){let e=super.toJSON(t);return e.object.zoom=this.zoom,e.object.left=this.left,e.object.right=this.right,e.object.top=this.top,e.object.bottom=this.bottom,e.object.near=this.near,e.object.far=this.far,this.view!==null&&(e.object.view=Object.assign({},this.view)),e}},Jc=class extends Zc{constructor(){super(new vo(-5,5,5,-5,.5,500)),this.isDirectionalLightShadow=!0}},Mo=class extends yo{constructor(t,e){super(t,e),this.isDirectionalLight=!0,this.type="DirectionalLight",this.position.copy(Oe.DEFAULT_UP),this.updateMatrix(),this.target=new Oe,this.shadow=new Jc}dispose(){this.shadow.dispose()}copy(t){return super.copy(t),this.target=t.target.clone(),this.shadow=t.shadow.clone(),this}};var Ja=class extends on{constructor(t=[]){super(),this.isArrayCamera=!0,this.cameras=t}};var xh="\\[\\]\\.:\\/",xm=new RegExp("["+xh+"]","g"),yh="[^"+xh+"]",ym="[^"+xh.replace("\\.","")+"]",_m=/((?:WC+[\/:])*)/.source.replace("WC",yh),vm=/(WCOD+)?/.source.replace("WCOD",ym),Mm=/(?:\.(WC+)(?:\[(.+)\])?)?/.source.replace("WC",yh),Em=/\.(WC+)(?:\[(.+)\])?/.source.replace("WC",yh),Sm=new RegExp("^"+_m+vm+Mm+Em+"$"),wm=["material","materials","bones","map"],Kc=class{constructor(t,e,i){let s=i||Ae.parseTrackName(e);this._targetGroup=t,this._bindings=t.subscribe_(e,s)}getValue(t,e){this.bind();let i=this._targetGroup.nCachedObjects_,s=this._bindings[i];s!==void 0&&s.getValue(t,e)}setValue(t,e){let i=this._bindings;for(let s=this._targetGroup.nCachedObjects_,r=i.length;s!==r;++s)i[s].setValue(t,e)}bind(){let t=this._bindings;for(let e=this._targetGroup.nCachedObjects_,i=t.length;e!==i;++e)t[e].bind()}unbind(){let t=this._bindings;for(let e=this._targetGroup.nCachedObjects_,i=t.length;e!==i;++e)t[e].unbind()}},Ae=class n{constructor(t,e,i){this.path=e,this.parsedPath=i||n.parseTrackName(e),this.node=n.findNode(t,this.parsedPath.nodeName),this.rootNode=t,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}static create(t,e,i){return t&&t.isAnimationObjectGroup?new n.Composite(t,e,i):new n(t,e,i)}static sanitizeNodeName(t){return t.replace(/\s/g,"_").replace(xm,"")}static parseTrackName(t){let e=Sm.exec(t);if(e===null)throw new Error("PropertyBinding: Cannot parse trackName: "+t);let i={nodeName:e[2],objectName:e[3],objectIndex:e[4],propertyName:e[5],propertyIndex:e[6]},s=i.nodeName&&i.nodeName.lastIndexOf(".");if(s!==void 0&&s!==-1){let r=i.nodeName.substring(s+1);wm.indexOf(r)!==-1&&(i.nodeName=i.nodeName.substring(0,s),i.objectName=r)}if(i.propertyName===null||i.propertyName.length===0)throw new Error("PropertyBinding: can not parse propertyName from trackName: "+t);return i}static findNode(t,e){if(e===void 0||e===""||e==="."||e===-1||e===t.name||e===t.uuid)return t;if(t.skeleton){let i=t.skeleton.getBoneByName(e);if(i!==void 0)return i}if(t.children){let i=function(r){for(let a=0;a<r.length;a++){let o=r[a];if(o.name===e||o.uuid===e)return o;let l=i(o.children);if(l)return l}return null},s=i(t.children);if(s)return s}return null}_getValue_unavailable(){}_setValue_unavailable(){}_getValue_direct(t,e){t[e]=this.targetObject[this.propertyName]}_getValue_array(t,e){let i=this.resolvedProperty;for(let s=0,r=i.length;s!==r;++s)t[e++]=i[s]}_getValue_arrayElement(t,e){t[e]=this.resolvedProperty[this.propertyIndex]}_getValue_toArray(t,e){this.resolvedProperty.toArray(t,e)}_setValue_direct(t,e){this.targetObject[this.propertyName]=t[e]}_setValue_direct_setNeedsUpdate(t,e){this.targetObject[this.propertyName]=t[e],this.targetObject.needsUpdate=!0}_setValue_direct_setMatrixWorldNeedsUpdate(t,e){this.targetObject[this.propertyName]=t[e],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_array(t,e){let i=this.resolvedProperty;for(let s=0,r=i.length;s!==r;++s)i[s]=t[e++]}_setValue_array_setNeedsUpdate(t,e){let i=this.resolvedProperty;for(let s=0,r=i.length;s!==r;++s)i[s]=t[e++];this.targetObject.needsUpdate=!0}_setValue_array_setMatrixWorldNeedsUpdate(t,e){let i=this.resolvedProperty;for(let s=0,r=i.length;s!==r;++s)i[s]=t[e++];this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_arrayElement(t,e){this.resolvedProperty[this.propertyIndex]=t[e]}_setValue_arrayElement_setNeedsUpdate(t,e){this.resolvedProperty[this.propertyIndex]=t[e],this.targetObject.needsUpdate=!0}_setValue_arrayElement_setMatrixWorldNeedsUpdate(t,e){this.resolvedProperty[this.propertyIndex]=t[e],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_fromArray(t,e){this.resolvedProperty.fromArray(t,e)}_setValue_fromArray_setNeedsUpdate(t,e){this.resolvedProperty.fromArray(t,e),this.targetObject.needsUpdate=!0}_setValue_fromArray_setMatrixWorldNeedsUpdate(t,e){this.resolvedProperty.fromArray(t,e),this.targetObject.matrixWorldNeedsUpdate=!0}_getValue_unbound(t,e){this.bind(),this.getValue(t,e)}_setValue_unbound(t,e){this.bind(),this.setValue(t,e)}bind(){let t=this.node,e=this.parsedPath,i=e.objectName,s=e.propertyName,r=e.propertyIndex;if(t||(t=n.findNode(this.rootNode,e.nodeName),this.node=t),this.getValue=this._getValue_unavailable,this.setValue=this._setValue_unavailable,!t){console.warn("THREE.PropertyBinding: No target node found for track: "+this.path+".");return}if(i){let c=e.objectIndex;switch(i){case"materials":if(!t.material){console.error("THREE.PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!t.material.materials){console.error("THREE.PropertyBinding: Can not bind to material.materials as node.material does not have a materials array.",this);return}t=t.material.materials;break;case"bones":if(!t.skeleton){console.error("THREE.PropertyBinding: Can not bind to bones as node does not have a skeleton.",this);return}t=t.skeleton.bones;for(let h=0;h<t.length;h++)if(t[h].name===c){c=h;break}break;case"map":if("map"in t){t=t.map;break}if(!t.material){console.error("THREE.PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!t.material.map){console.error("THREE.PropertyBinding: Can not bind to material.map as node.material does not have a map.",this);return}t=t.material.map;break;default:if(t[i]===void 0){console.error("THREE.PropertyBinding: Can not bind to objectName of node undefined.",this);return}t=t[i]}if(c!==void 0){if(t[c]===void 0){console.error("THREE.PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.",this,t);return}t=t[c]}}let a=t[s];if(a===void 0){let c=e.nodeName;console.error("THREE.PropertyBinding: Trying to update property for track: "+c+"."+s+" but it wasn't found.",t);return}let o=this.Versioning.None;this.targetObject=t,t.needsUpdate!==void 0?o=this.Versioning.NeedsUpdate:t.matrixWorldNeedsUpdate!==void 0&&(o=this.Versioning.MatrixWorldNeedsUpdate);let l=this.BindingType.Direct;if(r!==void 0){if(s==="morphTargetInfluences"){if(!t.geometry){console.error("THREE.PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.",this);return}if(!t.geometry.morphAttributes){console.error("THREE.PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.morphAttributes.",this);return}t.morphTargetDictionary[r]!==void 0&&(r=t.morphTargetDictionary[r])}l=this.BindingType.ArrayElement,this.resolvedProperty=a,this.propertyIndex=r}else a.fromArray!==void 0&&a.toArray!==void 0?(l=this.BindingType.HasFromToArray,this.resolvedProperty=a):Array.isArray(a)?(l=this.BindingType.EntireArray,this.resolvedProperty=a):this.propertyName=s;this.getValue=this.GetterByBindingType[l],this.setValue=this.SetterByBindingTypeAndVersioning[l][o]}unbind(){this.node=null,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}};Ae.Composite=Kc;Ae.prototype.BindingType={Direct:0,EntireArray:1,ArrayElement:2,HasFromToArray:3};Ae.prototype.Versioning={None:0,NeedsUpdate:1,MatrixWorldNeedsUpdate:2};Ae.prototype.GetterByBindingType=[Ae.prototype._getValue_direct,Ae.prototype._getValue_array,Ae.prototype._getValue_arrayElement,Ae.prototype._getValue_toArray];Ae.prototype.SetterByBindingTypeAndVersioning=[[Ae.prototype._setValue_direct,Ae.prototype._setValue_direct_setNeedsUpdate,Ae.prototype._setValue_direct_setMatrixWorldNeedsUpdate],[Ae.prototype._setValue_array,Ae.prototype._setValue_array_setNeedsUpdate,Ae.prototype._setValue_array_setMatrixWorldNeedsUpdate],[Ae.prototype._setValue_arrayElement,Ae.prototype._setValue_arrayElement_setNeedsUpdate,Ae.prototype._setValue_arrayElement_setMatrixWorldNeedsUpdate],[Ae.prototype._setValue_fromArray,Ae.prototype._setValue_fromArray_setNeedsUpdate,Ae.prototype._setValue_fromArray_setMatrixWorldNeedsUpdate]];var X_=new Float32Array(1);function _h(n,t,e,i){let s=Tm(i);switch(e){case oh:return n*t;case lh:return n*t;case ch:return n*t*2;case fl:return n*t/s.components*s.byteLength;case pl:return n*t/s.components*s.byteLength;case hh:return n*t*2/s.components*s.byteLength;case ml:return n*t*2/s.components*s.byteLength;case ah:return n*t*3/s.components*s.byteLength;case Un:return n*t*4/s.components*s.byteLength;case gl:return n*t*4/s.components*s.byteLength;case To:case bo:return Math.floor((n+3)/4)*Math.floor((t+3)/4)*8;case Ao:case Ro:return Math.floor((n+3)/4)*Math.floor((t+3)/4)*16;case yl:case vl:return Math.max(n,16)*Math.max(t,8)/4;case xl:case _l:return Math.max(n,8)*Math.max(t,8)/2;case Ml:case El:return Math.floor((n+3)/4)*Math.floor((t+3)/4)*8;case Sl:return Math.floor((n+3)/4)*Math.floor((t+3)/4)*16;case wl:return Math.floor((n+3)/4)*Math.floor((t+3)/4)*16;case Tl:return Math.floor((n+4)/5)*Math.floor((t+3)/4)*16;case bl:return Math.floor((n+4)/5)*Math.floor((t+4)/5)*16;case Al:return Math.floor((n+5)/6)*Math.floor((t+4)/5)*16;case Rl:return Math.floor((n+5)/6)*Math.floor((t+5)/6)*16;case Cl:return Math.floor((n+7)/8)*Math.floor((t+4)/5)*16;case Pl:return Math.floor((n+7)/8)*Math.floor((t+5)/6)*16;case Il:return Math.floor((n+7)/8)*Math.floor((t+7)/8)*16;case Ll:return Math.floor((n+9)/10)*Math.floor((t+4)/5)*16;case Dl:return Math.floor((n+9)/10)*Math.floor((t+5)/6)*16;case Ul:return Math.floor((n+9)/10)*Math.floor((t+7)/8)*16;case Nl:return Math.floor((n+9)/10)*Math.floor((t+9)/10)*16;case Fl:return Math.floor((n+11)/12)*Math.floor((t+9)/10)*16;case Ol:return Math.floor((n+11)/12)*Math.floor((t+11)/12)*16;case Co:case Hl:case Bl:return Math.ceil(n/4)*Math.ceil(t/4)*16;case uh:case kl:return Math.ceil(n/4)*Math.ceil(t/4)*8;case zl:case Gl:return Math.ceil(n/4)*Math.ceil(t/4)*16}throw new Error(`Unable to determine texture byte length for ${e} format.`)}function Tm(n){switch(n){case ai:case ih:return{byteLength:1,components:1};case _r:case sh:case vr:return{byteLength:2,components:1};case ul:case dl:return{byteLength:2,components:4};case ss:case hl:case Yn:return{byteLength:4,components:1};case rh:return{byteLength:4,components:3}}throw new Error(`Unknown texture type ${n}.`)}typeof __THREE_DEVTOOLS__!="undefined"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:"171"}}));typeof window!="undefined"&&(window.__THREE__?console.warn("WARNING: Multiple instances of Three.js being imported."):window.__THREE__="171");function mf(){let n=null,t=!1,e=null,i=null;function s(r,a){e(r,a),i=n.requestAnimationFrame(s)}return{start:function(){t!==!0&&e!==null&&(i=n.requestAnimationFrame(s),t=!0)},stop:function(){n.cancelAnimationFrame(i),t=!1},setAnimationLoop:function(r){e=r},setContext:function(r){n=r}}}function Am(n){let t=new WeakMap;function e(o,l){let c=o.array,h=o.usage,d=c.byteLength,u=n.createBuffer();n.bindBuffer(l,u),n.bufferData(l,c,h),o.onUploadCallback();let f;if(c instanceof Float32Array)f=n.FLOAT;else if(c instanceof Uint16Array)o.isFloat16BufferAttribute?f=n.HALF_FLOAT:f=n.UNSIGNED_SHORT;else if(c instanceof Int16Array)f=n.SHORT;else if(c instanceof Uint32Array)f=n.UNSIGNED_INT;else if(c instanceof Int32Array)f=n.INT;else if(c instanceof Int8Array)f=n.BYTE;else if(c instanceof Uint8Array)f=n.UNSIGNED_BYTE;else if(c instanceof Uint8ClampedArray)f=n.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+c);return{buffer:u,type:f,bytesPerElement:c.BYTES_PER_ELEMENT,version:o.version,size:d}}function i(o,l,c){let h=l.array,d=l.updateRanges;if(n.bindBuffer(c,o),d.length===0)n.bufferSubData(c,0,h);else{d.sort((f,x)=>f.start-x.start);let u=0;for(let f=1;f<d.length;f++){let x=d[u],M=d[f];M.start<=x.start+x.count+1?x.count=Math.max(x.count,M.start+M.count-x.start):(++u,d[u]=M)}d.length=u+1;for(let f=0,x=d.length;f<x;f++){let M=d[f];n.bufferSubData(c,M.start*h.BYTES_PER_ELEMENT,h,M.start,M.count)}l.clearUpdateRanges()}l.onUploadCallback()}function s(o){return o.isInterleavedBufferAttribute&&(o=o.data),t.get(o)}function r(o){o.isInterleavedBufferAttribute&&(o=o.data);let l=t.get(o);l&&(n.deleteBuffer(l.buffer),t.delete(o))}function a(o,l){if(o.isInterleavedBufferAttribute&&(o=o.data),o.isGLBufferAttribute){let h=t.get(o);(!h||h.version<o.version)&&t.set(o,{buffer:o.buffer,type:o.type,bytesPerElement:o.elementSize,version:o.version});return}let c=t.get(o);if(c===void 0)t.set(o,e(o,l));else if(c.version<o.version){if(c.size!==o.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");i(c.buffer,o,l),c.version=o.version}}return{get:s,remove:r,update:a}}var Rm=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,Cm=`#ifdef USE_ALPHAHASH
	const float ALPHA_HASH_SCALE = 0.05;
	float hash2D( vec2 value ) {
		return fract( 1.0e4 * sin( 17.0 * value.x + 0.1 * value.y ) * ( 0.1 + abs( sin( 13.0 * value.y + value.x ) ) ) );
	}
	float hash3D( vec3 value ) {
		return hash2D( vec2( hash2D( value.xy ), value.z ) );
	}
	float getAlphaHashThreshold( vec3 position ) {
		float maxDeriv = max(
			length( dFdx( position.xyz ) ),
			length( dFdy( position.xyz ) )
		);
		float pixScale = 1.0 / ( ALPHA_HASH_SCALE * maxDeriv );
		vec2 pixScales = vec2(
			exp2( floor( log2( pixScale ) ) ),
			exp2( ceil( log2( pixScale ) ) )
		);
		vec2 alpha = vec2(
			hash3D( floor( pixScales.x * position.xyz ) ),
			hash3D( floor( pixScales.y * position.xyz ) )
		);
		float lerpFactor = fract( log2( pixScale ) );
		float x = ( 1.0 - lerpFactor ) * alpha.x + lerpFactor * alpha.y;
		float a = min( lerpFactor, 1.0 - lerpFactor );
		vec3 cases = vec3(
			x * x / ( 2.0 * a * ( 1.0 - a ) ),
			( x - 0.5 * a ) / ( 1.0 - a ),
			1.0 - ( ( 1.0 - x ) * ( 1.0 - x ) / ( 2.0 * a * ( 1.0 - a ) ) )
		);
		float threshold = ( x < ( 1.0 - a ) )
			? ( ( x < a ) ? cases.x : cases.y )
			: cases.z;
		return clamp( threshold , 1.0e-6, 1.0 );
	}
#endif`,Pm=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,Im=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,Lm=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,Dm=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,Um=`#ifdef USE_AOMAP
	float ambientOcclusion = ( texture2D( aoMap, vAoMapUv ).r - 1.0 ) * aoMapIntensity + 1.0;
	reflectedLight.indirectDiffuse *= ambientOcclusion;
	#if defined( USE_CLEARCOAT ) 
		clearcoatSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_SHEEN ) 
		sheenSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD )
		float dotNV = saturate( dot( geometryNormal, geometryViewDir ) );
		reflectedLight.indirectSpecular *= computeSpecularOcclusion( dotNV, ambientOcclusion, material.roughness );
	#endif
#endif`,Nm=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,Fm=`#ifdef USE_BATCHING
	#if ! defined( GL_ANGLE_multi_draw )
	#define gl_DrawID _gl_DrawID
	uniform int _gl_DrawID;
	#endif
	uniform highp sampler2D batchingTexture;
	uniform highp usampler2D batchingIdTexture;
	mat4 getBatchingMatrix( const in float i ) {
		int size = textureSize( batchingTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( batchingTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( batchingTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( batchingTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( batchingTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
	float getIndirectIndex( const in int i ) {
		int size = textureSize( batchingIdTexture, 0 ).x;
		int x = i % size;
		int y = i / size;
		return float( texelFetch( batchingIdTexture, ivec2( x, y ), 0 ).r );
	}
#endif
#ifdef USE_BATCHING_COLOR
	uniform sampler2D batchingColorTexture;
	vec3 getBatchingColor( const in float i ) {
		int size = textureSize( batchingColorTexture, 0 ).x;
		int j = int( i );
		int x = j % size;
		int y = j / size;
		return texelFetch( batchingColorTexture, ivec2( x, y ), 0 ).rgb;
	}
#endif`,Om=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,Hm=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,Bm=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,km=`float G_BlinnPhong_Implicit( ) {
	return 0.25;
}
float D_BlinnPhong( const in float shininess, const in float dotNH ) {
	return RECIPROCAL_PI * ( shininess * 0.5 + 1.0 ) * pow( dotNH, shininess );
}
vec3 BRDF_BlinnPhong( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in vec3 specularColor, const in float shininess ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( specularColor, 1.0, dotVH );
	float G = G_BlinnPhong_Implicit( );
	float D = D_BlinnPhong( shininess, dotNH );
	return F * ( G * D );
} // validated`,zm=`#ifdef USE_IRIDESCENCE
	const mat3 XYZ_TO_REC709 = mat3(
		 3.2404542, -0.9692660,  0.0556434,
		-1.5371385,  1.8760108, -0.2040259,
		-0.4985314,  0.0415560,  1.0572252
	);
	vec3 Fresnel0ToIor( vec3 fresnel0 ) {
		vec3 sqrtF0 = sqrt( fresnel0 );
		return ( vec3( 1.0 ) + sqrtF0 ) / ( vec3( 1.0 ) - sqrtF0 );
	}
	vec3 IorToFresnel0( vec3 transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - vec3( incidentIor ) ) / ( transmittedIor + vec3( incidentIor ) ) );
	}
	float IorToFresnel0( float transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - incidentIor ) / ( transmittedIor + incidentIor ));
	}
	vec3 evalSensitivity( float OPD, vec3 shift ) {
		float phase = 2.0 * PI * OPD * 1.0e-9;
		vec3 val = vec3( 5.4856e-13, 4.4201e-13, 5.2481e-13 );
		vec3 pos = vec3( 1.6810e+06, 1.7953e+06, 2.2084e+06 );
		vec3 var = vec3( 4.3278e+09, 9.3046e+09, 6.6121e+09 );
		vec3 xyz = val * sqrt( 2.0 * PI * var ) * cos( pos * phase + shift ) * exp( - pow2( phase ) * var );
		xyz.x += 9.7470e-14 * sqrt( 2.0 * PI * 4.5282e+09 ) * cos( 2.2399e+06 * phase + shift[ 0 ] ) * exp( - 4.5282e+09 * pow2( phase ) );
		xyz /= 1.0685e-7;
		vec3 rgb = XYZ_TO_REC709 * xyz;
		return rgb;
	}
	vec3 evalIridescence( float outsideIOR, float eta2, float cosTheta1, float thinFilmThickness, vec3 baseF0 ) {
		vec3 I;
		float iridescenceIOR = mix( outsideIOR, eta2, smoothstep( 0.0, 0.03, thinFilmThickness ) );
		float sinTheta2Sq = pow2( outsideIOR / iridescenceIOR ) * ( 1.0 - pow2( cosTheta1 ) );
		float cosTheta2Sq = 1.0 - sinTheta2Sq;
		if ( cosTheta2Sq < 0.0 ) {
			return vec3( 1.0 );
		}
		float cosTheta2 = sqrt( cosTheta2Sq );
		float R0 = IorToFresnel0( iridescenceIOR, outsideIOR );
		float R12 = F_Schlick( R0, 1.0, cosTheta1 );
		float T121 = 1.0 - R12;
		float phi12 = 0.0;
		if ( iridescenceIOR < outsideIOR ) phi12 = PI;
		float phi21 = PI - phi12;
		vec3 baseIOR = Fresnel0ToIor( clamp( baseF0, 0.0, 0.9999 ) );		vec3 R1 = IorToFresnel0( baseIOR, iridescenceIOR );
		vec3 R23 = F_Schlick( R1, 1.0, cosTheta2 );
		vec3 phi23 = vec3( 0.0 );
		if ( baseIOR[ 0 ] < iridescenceIOR ) phi23[ 0 ] = PI;
		if ( baseIOR[ 1 ] < iridescenceIOR ) phi23[ 1 ] = PI;
		if ( baseIOR[ 2 ] < iridescenceIOR ) phi23[ 2 ] = PI;
		float OPD = 2.0 * iridescenceIOR * thinFilmThickness * cosTheta2;
		vec3 phi = vec3( phi21 ) + phi23;
		vec3 R123 = clamp( R12 * R23, 1e-5, 0.9999 );
		vec3 r123 = sqrt( R123 );
		vec3 Rs = pow2( T121 ) * R23 / ( vec3( 1.0 ) - R123 );
		vec3 C0 = R12 + Rs;
		I = C0;
		vec3 Cm = Rs - T121;
		for ( int m = 1; m <= 2; ++ m ) {
			Cm *= r123;
			vec3 Sm = 2.0 * evalSensitivity( float( m ) * OPD, float( m ) * phi );
			I += Cm * Sm;
		}
		return max( I, vec3( 0.0 ) );
	}
#endif`,Gm=`#ifdef USE_BUMPMAP
	uniform sampler2D bumpMap;
	uniform float bumpScale;
	vec2 dHdxy_fwd() {
		vec2 dSTdx = dFdx( vBumpMapUv );
		vec2 dSTdy = dFdy( vBumpMapUv );
		float Hll = bumpScale * texture2D( bumpMap, vBumpMapUv ).x;
		float dBx = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdx ).x - Hll;
		float dBy = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdy ).x - Hll;
		return vec2( dBx, dBy );
	}
	vec3 perturbNormalArb( vec3 surf_pos, vec3 surf_norm, vec2 dHdxy, float faceDirection ) {
		vec3 vSigmaX = normalize( dFdx( surf_pos.xyz ) );
		vec3 vSigmaY = normalize( dFdy( surf_pos.xyz ) );
		vec3 vN = surf_norm;
		vec3 R1 = cross( vSigmaY, vN );
		vec3 R2 = cross( vN, vSigmaX );
		float fDet = dot( vSigmaX, R1 ) * faceDirection;
		vec3 vGrad = sign( fDet ) * ( dHdxy.x * R1 + dHdxy.y * R2 );
		return normalize( abs( fDet ) * surf_norm - vGrad );
	}
#endif`,Vm=`#if NUM_CLIPPING_PLANES > 0
	vec4 plane;
	#ifdef ALPHA_TO_COVERAGE
		float distanceToPlane, distanceGradient;
		float clipOpacity = 1.0;
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
			distanceGradient = fwidth( distanceToPlane ) / 2.0;
			clipOpacity *= smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			if ( clipOpacity == 0.0 ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			float unionClipOpacity = 1.0;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
				distanceGradient = fwidth( distanceToPlane ) / 2.0;
				unionClipOpacity *= 1.0 - smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			}
			#pragma unroll_loop_end
			clipOpacity *= 1.0 - unionClipOpacity;
		#endif
		diffuseColor.a *= clipOpacity;
		if ( diffuseColor.a == 0.0 ) discard;
	#else
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			if ( dot( vClipPosition, plane.xyz ) > plane.w ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			bool clipped = true;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				clipped = ( dot( vClipPosition, plane.xyz ) > plane.w ) && clipped;
			}
			#pragma unroll_loop_end
			if ( clipped ) discard;
		#endif
	#endif
#endif`,Wm=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,Xm=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,qm=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,Ym=`#if defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#elif defined( USE_COLOR )
	diffuseColor.rgb *= vColor;
#endif`,$m=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR )
	varying vec3 vColor;
#endif`,Zm=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec3 vColor;
#endif`,Jm=`#if defined( USE_COLOR_ALPHA )
	vColor = vec4( 1.0 );
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	vColor = vec3( 1.0 );
#endif
#ifdef USE_COLOR
	vColor *= color;
#endif
#ifdef USE_INSTANCING_COLOR
	vColor.xyz *= instanceColor.xyz;
#endif
#ifdef USE_BATCHING_COLOR
	vec3 batchingColor = getBatchingColor( getIndirectIndex( gl_DrawID ) );
	vColor.xyz *= batchingColor.xyz;
#endif`,Km=`#define PI 3.141592653589793
#define PI2 6.283185307179586
#define PI_HALF 1.5707963267948966
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535
#define EPSILON 1e-6
#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
#define whiteComplement( a ) ( 1.0 - saturate( a ) )
float pow2( const in float x ) { return x*x; }
vec3 pow2( const in vec3 x ) { return x*x; }
float pow3( const in float x ) { return x*x*x; }
float pow4( const in float x ) { float x2 = x*x; return x2*x2; }
float max3( const in vec3 v ) { return max( max( v.x, v.y ), v.z ); }
float average( const in vec3 v ) { return dot( v, vec3( 0.3333333 ) ); }
highp float rand( const in vec2 uv ) {
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract( sin( sn ) * c );
}
#ifdef HIGH_PRECISION
	float precisionSafeLength( vec3 v ) { return length( v ); }
#else
	float precisionSafeLength( vec3 v ) {
		float maxComponent = max3( abs( v ) );
		return length( v / maxComponent ) * maxComponent;
	}
#endif
struct IncidentLight {
	vec3 color;
	vec3 direction;
	bool visible;
};
struct ReflectedLight {
	vec3 directDiffuse;
	vec3 directSpecular;
	vec3 indirectDiffuse;
	vec3 indirectSpecular;
};
#ifdef USE_ALPHAHASH
	varying vec3 vPosition;
#endif
vec3 transformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );
}
vec3 inverseTransformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( vec4( dir, 0.0 ) * matrix ).xyz );
}
mat3 transposeMat3( const in mat3 m ) {
	mat3 tmp;
	tmp[ 0 ] = vec3( m[ 0 ].x, m[ 1 ].x, m[ 2 ].x );
	tmp[ 1 ] = vec3( m[ 0 ].y, m[ 1 ].y, m[ 2 ].y );
	tmp[ 2 ] = vec3( m[ 0 ].z, m[ 1 ].z, m[ 2 ].z );
	return tmp;
}
bool isPerspectiveMatrix( mat4 m ) {
	return m[ 2 ][ 3 ] == - 1.0;
}
vec2 equirectUv( in vec3 dir ) {
	float u = atan( dir.z, dir.x ) * RECIPROCAL_PI2 + 0.5;
	float v = asin( clamp( dir.y, - 1.0, 1.0 ) ) * RECIPROCAL_PI + 0.5;
	return vec2( u, v );
}
vec3 BRDF_Lambert( const in vec3 diffuseColor ) {
	return RECIPROCAL_PI * diffuseColor;
}
vec3 F_Schlick( const in vec3 f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
}
float F_Schlick( const in float f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
} // validated`,Qm=`#ifdef ENVMAP_TYPE_CUBE_UV
	#define cubeUV_minMipLevel 4.0
	#define cubeUV_minTileSize 16.0
	float getFace( vec3 direction ) {
		vec3 absDirection = abs( direction );
		float face = - 1.0;
		if ( absDirection.x > absDirection.z ) {
			if ( absDirection.x > absDirection.y )
				face = direction.x > 0.0 ? 0.0 : 3.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		} else {
			if ( absDirection.z > absDirection.y )
				face = direction.z > 0.0 ? 2.0 : 5.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		}
		return face;
	}
	vec2 getUV( vec3 direction, float face ) {
		vec2 uv;
		if ( face == 0.0 ) {
			uv = vec2( direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 1.0 ) {
			uv = vec2( - direction.x, - direction.z ) / abs( direction.y );
		} else if ( face == 2.0 ) {
			uv = vec2( - direction.x, direction.y ) / abs( direction.z );
		} else if ( face == 3.0 ) {
			uv = vec2( - direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 4.0 ) {
			uv = vec2( - direction.x, direction.z ) / abs( direction.y );
		} else {
			uv = vec2( direction.x, direction.y ) / abs( direction.z );
		}
		return 0.5 * ( uv + 1.0 );
	}
	vec3 bilinearCubeUV( sampler2D envMap, vec3 direction, float mipInt ) {
		float face = getFace( direction );
		float filterInt = max( cubeUV_minMipLevel - mipInt, 0.0 );
		mipInt = max( mipInt, cubeUV_minMipLevel );
		float faceSize = exp2( mipInt );
		highp vec2 uv = getUV( direction, face ) * ( faceSize - 2.0 ) + 1.0;
		if ( face > 2.0 ) {
			uv.y += faceSize;
			face -= 3.0;
		}
		uv.x += face * faceSize;
		uv.x += filterInt * 3.0 * cubeUV_minTileSize;
		uv.y += 4.0 * ( exp2( CUBEUV_MAX_MIP ) - faceSize );
		uv.x *= CUBEUV_TEXEL_WIDTH;
		uv.y *= CUBEUV_TEXEL_HEIGHT;
		#ifdef texture2DGradEXT
			return texture2DGradEXT( envMap, uv, vec2( 0.0 ), vec2( 0.0 ) ).rgb;
		#else
			return texture2D( envMap, uv ).rgb;
		#endif
	}
	#define cubeUV_r0 1.0
	#define cubeUV_m0 - 2.0
	#define cubeUV_r1 0.8
	#define cubeUV_m1 - 1.0
	#define cubeUV_r4 0.4
	#define cubeUV_m4 2.0
	#define cubeUV_r5 0.305
	#define cubeUV_m5 3.0
	#define cubeUV_r6 0.21
	#define cubeUV_m6 4.0
	float roughnessToMip( float roughness ) {
		float mip = 0.0;
		if ( roughness >= cubeUV_r1 ) {
			mip = ( cubeUV_r0 - roughness ) * ( cubeUV_m1 - cubeUV_m0 ) / ( cubeUV_r0 - cubeUV_r1 ) + cubeUV_m0;
		} else if ( roughness >= cubeUV_r4 ) {
			mip = ( cubeUV_r1 - roughness ) * ( cubeUV_m4 - cubeUV_m1 ) / ( cubeUV_r1 - cubeUV_r4 ) + cubeUV_m1;
		} else if ( roughness >= cubeUV_r5 ) {
			mip = ( cubeUV_r4 - roughness ) * ( cubeUV_m5 - cubeUV_m4 ) / ( cubeUV_r4 - cubeUV_r5 ) + cubeUV_m4;
		} else if ( roughness >= cubeUV_r6 ) {
			mip = ( cubeUV_r5 - roughness ) * ( cubeUV_m6 - cubeUV_m5 ) / ( cubeUV_r5 - cubeUV_r6 ) + cubeUV_m5;
		} else {
			mip = - 2.0 * log2( 1.16 * roughness );		}
		return mip;
	}
	vec4 textureCubeUV( sampler2D envMap, vec3 sampleDir, float roughness ) {
		float mip = clamp( roughnessToMip( roughness ), cubeUV_m0, CUBEUV_MAX_MIP );
		float mipF = fract( mip );
		float mipInt = floor( mip );
		vec3 color0 = bilinearCubeUV( envMap, sampleDir, mipInt );
		if ( mipF == 0.0 ) {
			return vec4( color0, 1.0 );
		} else {
			vec3 color1 = bilinearCubeUV( envMap, sampleDir, mipInt + 1.0 );
			return vec4( mix( color0, color1, mipF ), 1.0 );
		}
	}
#endif`,jm=`vec3 transformedNormal = objectNormal;
#ifdef USE_TANGENT
	vec3 transformedTangent = objectTangent;
#endif
#ifdef USE_BATCHING
	mat3 bm = mat3( batchingMatrix );
	transformedNormal /= vec3( dot( bm[ 0 ], bm[ 0 ] ), dot( bm[ 1 ], bm[ 1 ] ), dot( bm[ 2 ], bm[ 2 ] ) );
	transformedNormal = bm * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = bm * transformedTangent;
	#endif
#endif
#ifdef USE_INSTANCING
	mat3 im = mat3( instanceMatrix );
	transformedNormal /= vec3( dot( im[ 0 ], im[ 0 ] ), dot( im[ 1 ], im[ 1 ] ), dot( im[ 2 ], im[ 2 ] ) );
	transformedNormal = im * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = im * transformedTangent;
	#endif
#endif
transformedNormal = normalMatrix * transformedNormal;
#ifdef FLIP_SIDED
	transformedNormal = - transformedNormal;
#endif
#ifdef USE_TANGENT
	transformedTangent = ( modelViewMatrix * vec4( transformedTangent, 0.0 ) ).xyz;
	#ifdef FLIP_SIDED
		transformedTangent = - transformedTangent;
	#endif
#endif`,t0=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,e0=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,n0=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	#ifdef DECODE_VIDEO_TEXTURE_EMISSIVE
		emissiveColor = sRGBTransferEOTF( emissiveColor );
	#endif
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,i0=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,s0="gl_FragColor = linearToOutputTexel( gl_FragColor );",r0=`vec4 LinearTransferOETF( in vec4 value ) {
	return value;
}
vec4 sRGBTransferEOTF( in vec4 value ) {
	return vec4( mix( pow( value.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), value.rgb * 0.0773993808, vec3( lessThanEqual( value.rgb, vec3( 0.04045 ) ) ) ), value.a );
}
vec4 sRGBTransferOETF( in vec4 value ) {
	return vec4( mix( pow( value.rgb, vec3( 0.41666 ) ) * 1.055 - vec3( 0.055 ), value.rgb * 12.92, vec3( lessThanEqual( value.rgb, vec3( 0.0031308 ) ) ) ), value.a );
}`,o0=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vec3 cameraToFrag;
		if ( isOrthographic ) {
			cameraToFrag = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToFrag = normalize( vWorldPosition - cameraPosition );
		}
		vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vec3 reflectVec = reflect( cameraToFrag, worldNormal );
		#else
			vec3 reflectVec = refract( cameraToFrag, worldNormal, refractionRatio );
		#endif
	#else
		vec3 reflectVec = vReflect;
	#endif
	#ifdef ENVMAP_TYPE_CUBE
		vec4 envColor = textureCube( envMap, envMapRotation * vec3( flipEnvMap * reflectVec.x, reflectVec.yz ) );
	#else
		vec4 envColor = vec4( 0.0 );
	#endif
	#ifdef ENVMAP_BLENDING_MULTIPLY
		outgoingLight = mix( outgoingLight, outgoingLight * envColor.xyz, specularStrength * reflectivity );
	#elif defined( ENVMAP_BLENDING_MIX )
		outgoingLight = mix( outgoingLight, envColor.xyz, specularStrength * reflectivity );
	#elif defined( ENVMAP_BLENDING_ADD )
		outgoingLight += envColor.xyz * specularStrength * reflectivity;
	#endif
#endif`,a0=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform float flipEnvMap;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
	
#endif`,l0=`#ifdef USE_ENVMAP
	uniform float reflectivity;
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		varying vec3 vWorldPosition;
		uniform float refractionRatio;
	#else
		varying vec3 vReflect;
	#endif
#endif`,c0=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,h0=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vWorldPosition = worldPosition.xyz;
	#else
		vec3 cameraToVertex;
		if ( isOrthographic ) {
			cameraToVertex = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToVertex = normalize( worldPosition.xyz - cameraPosition );
		}
		vec3 worldNormal = inverseTransformDirection( transformedNormal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vReflect = reflect( cameraToVertex, worldNormal );
		#else
			vReflect = refract( cameraToVertex, worldNormal, refractionRatio );
		#endif
	#endif
#endif`,u0=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,d0=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,f0=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,p0=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,m0=`#ifdef USE_GRADIENTMAP
	uniform sampler2D gradientMap;
#endif
vec3 getGradientIrradiance( vec3 normal, vec3 lightDirection ) {
	float dotNL = dot( normal, lightDirection );
	vec2 coord = vec2( dotNL * 0.5 + 0.5, 0.0 );
	#ifdef USE_GRADIENTMAP
		return vec3( texture2D( gradientMap, coord ).r );
	#else
		vec2 fw = fwidth( coord ) * 0.5;
		return mix( vec3( 0.7 ), vec3( 1.0 ), smoothstep( 0.7 - fw.x, 0.7 + fw.x, coord.x ) );
	#endif
}`,g0=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,x0=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,y0=`varying vec3 vViewPosition;
struct LambertMaterial {
	vec3 diffuseColor;
	float specularStrength;
};
void RE_Direct_Lambert( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Lambert( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Lambert
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,_0=`uniform bool receiveShadow;
uniform vec3 ambientLightColor;
#if defined( USE_LIGHT_PROBES )
	uniform vec3 lightProbe[ 9 ];
#endif
vec3 shGetIrradianceAt( in vec3 normal, in vec3 shCoefficients[ 9 ] ) {
	float x = normal.x, y = normal.y, z = normal.z;
	vec3 result = shCoefficients[ 0 ] * 0.886227;
	result += shCoefficients[ 1 ] * 2.0 * 0.511664 * y;
	result += shCoefficients[ 2 ] * 2.0 * 0.511664 * z;
	result += shCoefficients[ 3 ] * 2.0 * 0.511664 * x;
	result += shCoefficients[ 4 ] * 2.0 * 0.429043 * x * y;
	result += shCoefficients[ 5 ] * 2.0 * 0.429043 * y * z;
	result += shCoefficients[ 6 ] * ( 0.743125 * z * z - 0.247708 );
	result += shCoefficients[ 7 ] * 2.0 * 0.429043 * x * z;
	result += shCoefficients[ 8 ] * 0.429043 * ( x * x - y * y );
	return result;
}
vec3 getLightProbeIrradiance( const in vec3 lightProbe[ 9 ], const in vec3 normal ) {
	vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
	vec3 irradiance = shGetIrradianceAt( worldNormal, lightProbe );
	return irradiance;
}
vec3 getAmbientLightIrradiance( const in vec3 ambientLightColor ) {
	vec3 irradiance = ambientLightColor;
	return irradiance;
}
float getDistanceAttenuation( const in float lightDistance, const in float cutoffDistance, const in float decayExponent ) {
	float distanceFalloff = 1.0 / max( pow( lightDistance, decayExponent ), 0.01 );
	if ( cutoffDistance > 0.0 ) {
		distanceFalloff *= pow2( saturate( 1.0 - pow4( lightDistance / cutoffDistance ) ) );
	}
	return distanceFalloff;
}
float getSpotAttenuation( const in float coneCosine, const in float penumbraCosine, const in float angleCosine ) {
	return smoothstep( coneCosine, penumbraCosine, angleCosine );
}
#if NUM_DIR_LIGHTS > 0
	struct DirectionalLight {
		vec3 direction;
		vec3 color;
	};
	uniform DirectionalLight directionalLights[ NUM_DIR_LIGHTS ];
	void getDirectionalLightInfo( const in DirectionalLight directionalLight, out IncidentLight light ) {
		light.color = directionalLight.color;
		light.direction = directionalLight.direction;
		light.visible = true;
	}
#endif
#if NUM_POINT_LIGHTS > 0
	struct PointLight {
		vec3 position;
		vec3 color;
		float distance;
		float decay;
	};
	uniform PointLight pointLights[ NUM_POINT_LIGHTS ];
	void getPointLightInfo( const in PointLight pointLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = pointLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float lightDistance = length( lVector );
		light.color = pointLight.color;
		light.color *= getDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );
		light.visible = ( light.color != vec3( 0.0 ) );
	}
#endif
#if NUM_SPOT_LIGHTS > 0
	struct SpotLight {
		vec3 position;
		vec3 direction;
		vec3 color;
		float distance;
		float decay;
		float coneCos;
		float penumbraCos;
	};
	uniform SpotLight spotLights[ NUM_SPOT_LIGHTS ];
	void getSpotLightInfo( const in SpotLight spotLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = spotLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float angleCos = dot( light.direction, spotLight.direction );
		float spotAttenuation = getSpotAttenuation( spotLight.coneCos, spotLight.penumbraCos, angleCos );
		if ( spotAttenuation > 0.0 ) {
			float lightDistance = length( lVector );
			light.color = spotLight.color * spotAttenuation;
			light.color *= getDistanceAttenuation( lightDistance, spotLight.distance, spotLight.decay );
			light.visible = ( light.color != vec3( 0.0 ) );
		} else {
			light.color = vec3( 0.0 );
			light.visible = false;
		}
	}
#endif
#if NUM_RECT_AREA_LIGHTS > 0
	struct RectAreaLight {
		vec3 color;
		vec3 position;
		vec3 halfWidth;
		vec3 halfHeight;
	};
	uniform sampler2D ltc_1;	uniform sampler2D ltc_2;
	uniform RectAreaLight rectAreaLights[ NUM_RECT_AREA_LIGHTS ];
#endif
#if NUM_HEMI_LIGHTS > 0
	struct HemisphereLight {
		vec3 direction;
		vec3 skyColor;
		vec3 groundColor;
	};
	uniform HemisphereLight hemisphereLights[ NUM_HEMI_LIGHTS ];
	vec3 getHemisphereLightIrradiance( const in HemisphereLight hemiLight, const in vec3 normal ) {
		float dotNL = dot( normal, hemiLight.direction );
		float hemiDiffuseWeight = 0.5 * dotNL + 0.5;
		vec3 irradiance = mix( hemiLight.groundColor, hemiLight.skyColor, hemiDiffuseWeight );
		return irradiance;
	}
#endif`,v0=`#ifdef USE_ENVMAP
	vec3 getIBLIrradiance( const in vec3 normal ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * worldNormal, 1.0 );
			return PI * envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	vec3 getIBLRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 reflectVec = reflect( - viewDir, normal );
			reflectVec = normalize( mix( reflectVec, normal, roughness * roughness) );
			reflectVec = inverseTransformDirection( reflectVec, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * reflectVec, roughness );
			return envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	#ifdef USE_ANISOTROPY
		vec3 getIBLAnisotropyRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness, const in vec3 bitangent, const in float anisotropy ) {
			#ifdef ENVMAP_TYPE_CUBE_UV
				vec3 bentNormal = cross( bitangent, viewDir );
				bentNormal = normalize( cross( bentNormal, bitangent ) );
				bentNormal = normalize( mix( bentNormal, normal, pow2( pow2( 1.0 - anisotropy * ( 1.0 - roughness ) ) ) ) );
				return getIBLRadiance( viewDir, bentNormal, roughness );
			#else
				return vec3( 0.0 );
			#endif
		}
	#endif
#endif`,M0=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,E0=`varying vec3 vViewPosition;
struct ToonMaterial {
	vec3 diffuseColor;
};
void RE_Direct_Toon( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	vec3 irradiance = getGradientIrradiance( geometryNormal, directLight.direction ) * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Toon( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Toon
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,S0=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,w0=`varying vec3 vViewPosition;
struct BlinnPhongMaterial {
	vec3 diffuseColor;
	vec3 specularColor;
	float specularShininess;
	float specularStrength;
};
void RE_Direct_BlinnPhong( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
	reflectedLight.directSpecular += irradiance * BRDF_BlinnPhong( directLight.direction, geometryViewDir, geometryNormal, material.specularColor, material.specularShininess ) * material.specularStrength;
}
void RE_IndirectDiffuse_BlinnPhong( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_BlinnPhong
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,T0=`PhysicalMaterial material;
material.diffuseColor = diffuseColor.rgb * ( 1.0 - metalnessFactor );
vec3 dxy = max( abs( dFdx( nonPerturbedNormal ) ), abs( dFdy( nonPerturbedNormal ) ) );
float geometryRoughness = max( max( dxy.x, dxy.y ), dxy.z );
material.roughness = max( roughnessFactor, 0.0525 );material.roughness += geometryRoughness;
material.roughness = min( material.roughness, 1.0 );
#ifdef IOR
	material.ior = ior;
	#ifdef USE_SPECULAR
		float specularIntensityFactor = specularIntensity;
		vec3 specularColorFactor = specularColor;
		#ifdef USE_SPECULAR_COLORMAP
			specularColorFactor *= texture2D( specularColorMap, vSpecularColorMapUv ).rgb;
		#endif
		#ifdef USE_SPECULAR_INTENSITYMAP
			specularIntensityFactor *= texture2D( specularIntensityMap, vSpecularIntensityMapUv ).a;
		#endif
		material.specularF90 = mix( specularIntensityFactor, 1.0, metalnessFactor );
	#else
		float specularIntensityFactor = 1.0;
		vec3 specularColorFactor = vec3( 1.0 );
		material.specularF90 = 1.0;
	#endif
	material.specularColor = mix( min( pow2( ( material.ior - 1.0 ) / ( material.ior + 1.0 ) ) * specularColorFactor, vec3( 1.0 ) ) * specularIntensityFactor, diffuseColor.rgb, metalnessFactor );
#else
	material.specularColor = mix( vec3( 0.04 ), diffuseColor.rgb, metalnessFactor );
	material.specularF90 = 1.0;
#endif
#ifdef USE_CLEARCOAT
	material.clearcoat = clearcoat;
	material.clearcoatRoughness = clearcoatRoughness;
	material.clearcoatF0 = vec3( 0.04 );
	material.clearcoatF90 = 1.0;
	#ifdef USE_CLEARCOATMAP
		material.clearcoat *= texture2D( clearcoatMap, vClearcoatMapUv ).x;
	#endif
	#ifdef USE_CLEARCOAT_ROUGHNESSMAP
		material.clearcoatRoughness *= texture2D( clearcoatRoughnessMap, vClearcoatRoughnessMapUv ).y;
	#endif
	material.clearcoat = saturate( material.clearcoat );	material.clearcoatRoughness = max( material.clearcoatRoughness, 0.0525 );
	material.clearcoatRoughness += geometryRoughness;
	material.clearcoatRoughness = min( material.clearcoatRoughness, 1.0 );
#endif
#ifdef USE_DISPERSION
	material.dispersion = dispersion;
#endif
#ifdef USE_IRIDESCENCE
	material.iridescence = iridescence;
	material.iridescenceIOR = iridescenceIOR;
	#ifdef USE_IRIDESCENCEMAP
		material.iridescence *= texture2D( iridescenceMap, vIridescenceMapUv ).r;
	#endif
	#ifdef USE_IRIDESCENCE_THICKNESSMAP
		material.iridescenceThickness = (iridescenceThicknessMaximum - iridescenceThicknessMinimum) * texture2D( iridescenceThicknessMap, vIridescenceThicknessMapUv ).g + iridescenceThicknessMinimum;
	#else
		material.iridescenceThickness = iridescenceThicknessMaximum;
	#endif
#endif
#ifdef USE_SHEEN
	material.sheenColor = sheenColor;
	#ifdef USE_SHEEN_COLORMAP
		material.sheenColor *= texture2D( sheenColorMap, vSheenColorMapUv ).rgb;
	#endif
	material.sheenRoughness = clamp( sheenRoughness, 0.07, 1.0 );
	#ifdef USE_SHEEN_ROUGHNESSMAP
		material.sheenRoughness *= texture2D( sheenRoughnessMap, vSheenRoughnessMapUv ).a;
	#endif
#endif
#ifdef USE_ANISOTROPY
	#ifdef USE_ANISOTROPYMAP
		mat2 anisotropyMat = mat2( anisotropyVector.x, anisotropyVector.y, - anisotropyVector.y, anisotropyVector.x );
		vec3 anisotropyPolar = texture2D( anisotropyMap, vAnisotropyMapUv ).rgb;
		vec2 anisotropyV = anisotropyMat * normalize( 2.0 * anisotropyPolar.rg - vec2( 1.0 ) ) * anisotropyPolar.b;
	#else
		vec2 anisotropyV = anisotropyVector;
	#endif
	material.anisotropy = length( anisotropyV );
	if( material.anisotropy == 0.0 ) {
		anisotropyV = vec2( 1.0, 0.0 );
	} else {
		anisotropyV /= material.anisotropy;
		material.anisotropy = saturate( material.anisotropy );
	}
	material.alphaT = mix( pow2( material.roughness ), 1.0, pow2( material.anisotropy ) );
	material.anisotropyT = tbn[ 0 ] * anisotropyV.x + tbn[ 1 ] * anisotropyV.y;
	material.anisotropyB = tbn[ 1 ] * anisotropyV.x - tbn[ 0 ] * anisotropyV.y;
#endif`,b0=`struct PhysicalMaterial {
	vec3 diffuseColor;
	float roughness;
	vec3 specularColor;
	float specularF90;
	float dispersion;
	#ifdef USE_CLEARCOAT
		float clearcoat;
		float clearcoatRoughness;
		vec3 clearcoatF0;
		float clearcoatF90;
	#endif
	#ifdef USE_IRIDESCENCE
		float iridescence;
		float iridescenceIOR;
		float iridescenceThickness;
		vec3 iridescenceFresnel;
		vec3 iridescenceF0;
	#endif
	#ifdef USE_SHEEN
		vec3 sheenColor;
		float sheenRoughness;
	#endif
	#ifdef IOR
		float ior;
	#endif
	#ifdef USE_TRANSMISSION
		float transmission;
		float transmissionAlpha;
		float thickness;
		float attenuationDistance;
		vec3 attenuationColor;
	#endif
	#ifdef USE_ANISOTROPY
		float anisotropy;
		float alphaT;
		vec3 anisotropyT;
		vec3 anisotropyB;
	#endif
};
vec3 clearcoatSpecularDirect = vec3( 0.0 );
vec3 clearcoatSpecularIndirect = vec3( 0.0 );
vec3 sheenSpecularDirect = vec3( 0.0 );
vec3 sheenSpecularIndirect = vec3(0.0 );
vec3 Schlick_to_F0( const in vec3 f, const in float f90, const in float dotVH ) {
    float x = clamp( 1.0 - dotVH, 0.0, 1.0 );
    float x2 = x * x;
    float x5 = clamp( x * x2 * x2, 0.0, 0.9999 );
    return ( f - vec3( f90 ) * x5 ) / ( 1.0 - x5 );
}
float V_GGX_SmithCorrelated( const in float alpha, const in float dotNL, const in float dotNV ) {
	float a2 = pow2( alpha );
	float gv = dotNL * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNV ) );
	float gl = dotNV * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNL ) );
	return 0.5 / max( gv + gl, EPSILON );
}
float D_GGX( const in float alpha, const in float dotNH ) {
	float a2 = pow2( alpha );
	float denom = pow2( dotNH ) * ( a2 - 1.0 ) + 1.0;
	return RECIPROCAL_PI * a2 / pow2( denom );
}
#ifdef USE_ANISOTROPY
	float V_GGX_SmithCorrelated_Anisotropic( const in float alphaT, const in float alphaB, const in float dotTV, const in float dotBV, const in float dotTL, const in float dotBL, const in float dotNV, const in float dotNL ) {
		float gv = dotNL * length( vec3( alphaT * dotTV, alphaB * dotBV, dotNV ) );
		float gl = dotNV * length( vec3( alphaT * dotTL, alphaB * dotBL, dotNL ) );
		float v = 0.5 / ( gv + gl );
		return saturate(v);
	}
	float D_GGX_Anisotropic( const in float alphaT, const in float alphaB, const in float dotNH, const in float dotTH, const in float dotBH ) {
		float a2 = alphaT * alphaB;
		highp vec3 v = vec3( alphaB * dotTH, alphaT * dotBH, a2 * dotNH );
		highp float v2 = dot( v, v );
		float w2 = a2 / v2;
		return RECIPROCAL_PI * a2 * pow2 ( w2 );
	}
#endif
#ifdef USE_CLEARCOAT
	vec3 BRDF_GGX_Clearcoat( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material) {
		vec3 f0 = material.clearcoatF0;
		float f90 = material.clearcoatF90;
		float roughness = material.clearcoatRoughness;
		float alpha = pow2( roughness );
		vec3 halfDir = normalize( lightDir + viewDir );
		float dotNL = saturate( dot( normal, lightDir ) );
		float dotNV = saturate( dot( normal, viewDir ) );
		float dotNH = saturate( dot( normal, halfDir ) );
		float dotVH = saturate( dot( viewDir, halfDir ) );
		vec3 F = F_Schlick( f0, f90, dotVH );
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
		return F * ( V * D );
	}
#endif
vec3 BRDF_GGX( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material ) {
	vec3 f0 = material.specularColor;
	float f90 = material.specularF90;
	float roughness = material.roughness;
	float alpha = pow2( roughness );
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( f0, f90, dotVH );
	#ifdef USE_IRIDESCENCE
		F = mix( F, material.iridescenceFresnel, material.iridescence );
	#endif
	#ifdef USE_ANISOTROPY
		float dotTL = dot( material.anisotropyT, lightDir );
		float dotTV = dot( material.anisotropyT, viewDir );
		float dotTH = dot( material.anisotropyT, halfDir );
		float dotBL = dot( material.anisotropyB, lightDir );
		float dotBV = dot( material.anisotropyB, viewDir );
		float dotBH = dot( material.anisotropyB, halfDir );
		float V = V_GGX_SmithCorrelated_Anisotropic( material.alphaT, alpha, dotTV, dotBV, dotTL, dotBL, dotNV, dotNL );
		float D = D_GGX_Anisotropic( material.alphaT, alpha, dotNH, dotTH, dotBH );
	#else
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
	#endif
	return F * ( V * D );
}
vec2 LTC_Uv( const in vec3 N, const in vec3 V, const in float roughness ) {
	const float LUT_SIZE = 64.0;
	const float LUT_SCALE = ( LUT_SIZE - 1.0 ) / LUT_SIZE;
	const float LUT_BIAS = 0.5 / LUT_SIZE;
	float dotNV = saturate( dot( N, V ) );
	vec2 uv = vec2( roughness, sqrt( 1.0 - dotNV ) );
	uv = uv * LUT_SCALE + LUT_BIAS;
	return uv;
}
float LTC_ClippedSphereFormFactor( const in vec3 f ) {
	float l = length( f );
	return max( ( l * l + f.z ) / ( l + 1.0 ), 0.0 );
}
vec3 LTC_EdgeVectorFormFactor( const in vec3 v1, const in vec3 v2 ) {
	float x = dot( v1, v2 );
	float y = abs( x );
	float a = 0.8543985 + ( 0.4965155 + 0.0145206 * y ) * y;
	float b = 3.4175940 + ( 4.1616724 + y ) * y;
	float v = a / b;
	float theta_sintheta = ( x > 0.0 ) ? v : 0.5 * inversesqrt( max( 1.0 - x * x, 1e-7 ) ) - v;
	return cross( v1, v2 ) * theta_sintheta;
}
vec3 LTC_Evaluate( const in vec3 N, const in vec3 V, const in vec3 P, const in mat3 mInv, const in vec3 rectCoords[ 4 ] ) {
	vec3 v1 = rectCoords[ 1 ] - rectCoords[ 0 ];
	vec3 v2 = rectCoords[ 3 ] - rectCoords[ 0 ];
	vec3 lightNormal = cross( v1, v2 );
	if( dot( lightNormal, P - rectCoords[ 0 ] ) < 0.0 ) return vec3( 0.0 );
	vec3 T1, T2;
	T1 = normalize( V - N * dot( V, N ) );
	T2 = - cross( N, T1 );
	mat3 mat = mInv * transposeMat3( mat3( T1, T2, N ) );
	vec3 coords[ 4 ];
	coords[ 0 ] = mat * ( rectCoords[ 0 ] - P );
	coords[ 1 ] = mat * ( rectCoords[ 1 ] - P );
	coords[ 2 ] = mat * ( rectCoords[ 2 ] - P );
	coords[ 3 ] = mat * ( rectCoords[ 3 ] - P );
	coords[ 0 ] = normalize( coords[ 0 ] );
	coords[ 1 ] = normalize( coords[ 1 ] );
	coords[ 2 ] = normalize( coords[ 2 ] );
	coords[ 3 ] = normalize( coords[ 3 ] );
	vec3 vectorFormFactor = vec3( 0.0 );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 0 ], coords[ 1 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 1 ], coords[ 2 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 2 ], coords[ 3 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 3 ], coords[ 0 ] );
	float result = LTC_ClippedSphereFormFactor( vectorFormFactor );
	return vec3( result );
}
#if defined( USE_SHEEN )
float D_Charlie( float roughness, float dotNH ) {
	float alpha = pow2( roughness );
	float invAlpha = 1.0 / alpha;
	float cos2h = dotNH * dotNH;
	float sin2h = max( 1.0 - cos2h, 0.0078125 );
	return ( 2.0 + invAlpha ) * pow( sin2h, invAlpha * 0.5 ) / ( 2.0 * PI );
}
float V_Neubelt( float dotNV, float dotNL ) {
	return saturate( 1.0 / ( 4.0 * ( dotNL + dotNV - dotNL * dotNV ) ) );
}
vec3 BRDF_Sheen( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, vec3 sheenColor, const in float sheenRoughness ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float D = D_Charlie( sheenRoughness, dotNH );
	float V = V_Neubelt( dotNV, dotNL );
	return sheenColor * ( D * V );
}
#endif
float IBLSheenBRDF( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	float r2 = roughness * roughness;
	float a = roughness < 0.25 ? -339.2 * r2 + 161.4 * roughness - 25.9 : -8.48 * r2 + 14.3 * roughness - 9.95;
	float b = roughness < 0.25 ? 44.0 * r2 - 23.7 * roughness + 3.26 : 1.97 * r2 - 3.27 * roughness + 0.72;
	float DG = exp( a * dotNV + b ) + ( roughness < 0.25 ? 0.0 : 0.1 * ( roughness - 0.25 ) );
	return saturate( DG * RECIPROCAL_PI );
}
vec2 DFGApprox( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	const vec4 c0 = vec4( - 1, - 0.0275, - 0.572, 0.022 );
	const vec4 c1 = vec4( 1, 0.0425, 1.04, - 0.04 );
	vec4 r = roughness * c0 + c1;
	float a004 = min( r.x * r.x, exp2( - 9.28 * dotNV ) ) * r.x + r.y;
	vec2 fab = vec2( - 1.04, 1.04 ) * a004 + r.zw;
	return fab;
}
vec3 EnvironmentBRDF( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness ) {
	vec2 fab = DFGApprox( normal, viewDir, roughness );
	return specularColor * fab.x + specularF90 * fab.y;
}
#ifdef USE_IRIDESCENCE
void computeMultiscatteringIridescence( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float iridescence, const in vec3 iridescenceF0, const in float roughness, inout vec3 singleScatter, inout vec3 multiScatter ) {
#else
void computeMultiscattering( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness, inout vec3 singleScatter, inout vec3 multiScatter ) {
#endif
	vec2 fab = DFGApprox( normal, viewDir, roughness );
	#ifdef USE_IRIDESCENCE
		vec3 Fr = mix( specularColor, iridescenceF0, iridescence );
	#else
		vec3 Fr = specularColor;
	#endif
	vec3 FssEss = Fr * fab.x + specularF90 * fab.y;
	float Ess = fab.x + fab.y;
	float Ems = 1.0 - Ess;
	vec3 Favg = Fr + ( 1.0 - Fr ) * 0.047619;	vec3 Fms = FssEss * Favg / ( 1.0 - Ems * Favg );
	singleScatter += FssEss;
	multiScatter += Fms * Ems;
}
#if NUM_RECT_AREA_LIGHTS > 0
	void RE_Direct_RectArea_Physical( const in RectAreaLight rectAreaLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
		vec3 normal = geometryNormal;
		vec3 viewDir = geometryViewDir;
		vec3 position = geometryPosition;
		vec3 lightPos = rectAreaLight.position;
		vec3 halfWidth = rectAreaLight.halfWidth;
		vec3 halfHeight = rectAreaLight.halfHeight;
		vec3 lightColor = rectAreaLight.color;
		float roughness = material.roughness;
		vec3 rectCoords[ 4 ];
		rectCoords[ 0 ] = lightPos + halfWidth - halfHeight;		rectCoords[ 1 ] = lightPos - halfWidth - halfHeight;
		rectCoords[ 2 ] = lightPos - halfWidth + halfHeight;
		rectCoords[ 3 ] = lightPos + halfWidth + halfHeight;
		vec2 uv = LTC_Uv( normal, viewDir, roughness );
		vec4 t1 = texture2D( ltc_1, uv );
		vec4 t2 = texture2D( ltc_2, uv );
		mat3 mInv = mat3(
			vec3( t1.x, 0, t1.y ),
			vec3(    0, 1,    0 ),
			vec3( t1.z, 0, t1.w )
		);
		vec3 fresnel = ( material.specularColor * t2.x + ( vec3( 1.0 ) - material.specularColor ) * t2.y );
		reflectedLight.directSpecular += lightColor * fresnel * LTC_Evaluate( normal, viewDir, position, mInv, rectCoords );
		reflectedLight.directDiffuse += lightColor * material.diffuseColor * LTC_Evaluate( normal, viewDir, position, mat3( 1.0 ), rectCoords );
	}
#endif
void RE_Direct_Physical( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	#ifdef USE_CLEARCOAT
		float dotNLcc = saturate( dot( geometryClearcoatNormal, directLight.direction ) );
		vec3 ccIrradiance = dotNLcc * directLight.color;
		clearcoatSpecularDirect += ccIrradiance * BRDF_GGX_Clearcoat( directLight.direction, geometryViewDir, geometryClearcoatNormal, material );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularDirect += irradiance * BRDF_Sheen( directLight.direction, geometryViewDir, geometryNormal, material.sheenColor, material.sheenRoughness );
	#endif
	reflectedLight.directSpecular += irradiance * BRDF_GGX( directLight.direction, geometryViewDir, geometryNormal, material );
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Physical( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectSpecular_Physical( const in vec3 radiance, const in vec3 irradiance, const in vec3 clearcoatRadiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight) {
	#ifdef USE_CLEARCOAT
		clearcoatSpecularIndirect += clearcoatRadiance * EnvironmentBRDF( geometryClearcoatNormal, geometryViewDir, material.clearcoatF0, material.clearcoatF90, material.clearcoatRoughness );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularIndirect += irradiance * material.sheenColor * IBLSheenBRDF( geometryNormal, geometryViewDir, material.sheenRoughness );
	#endif
	vec3 singleScattering = vec3( 0.0 );
	vec3 multiScattering = vec3( 0.0 );
	vec3 cosineWeightedIrradiance = irradiance * RECIPROCAL_PI;
	#ifdef USE_IRIDESCENCE
		computeMultiscatteringIridescence( geometryNormal, geometryViewDir, material.specularColor, material.specularF90, material.iridescence, material.iridescenceFresnel, material.roughness, singleScattering, multiScattering );
	#else
		computeMultiscattering( geometryNormal, geometryViewDir, material.specularColor, material.specularF90, material.roughness, singleScattering, multiScattering );
	#endif
	vec3 totalScattering = singleScattering + multiScattering;
	vec3 diffuse = material.diffuseColor * ( 1.0 - max( max( totalScattering.r, totalScattering.g ), totalScattering.b ) );
	reflectedLight.indirectSpecular += radiance * singleScattering;
	reflectedLight.indirectSpecular += multiScattering * cosineWeightedIrradiance;
	reflectedLight.indirectDiffuse += diffuse * cosineWeightedIrradiance;
}
#define RE_Direct				RE_Direct_Physical
#define RE_Direct_RectArea		RE_Direct_RectArea_Physical
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Physical
#define RE_IndirectSpecular		RE_IndirectSpecular_Physical
float computeSpecularOcclusion( const in float dotNV, const in float ambientOcclusion, const in float roughness ) {
	return saturate( pow( dotNV + ambientOcclusion, exp2( - 16.0 * roughness - 1.0 ) ) - 1.0 + ambientOcclusion );
}`,A0=`
vec3 geometryPosition = - vViewPosition;
vec3 geometryNormal = normal;
vec3 geometryViewDir = ( isOrthographic ) ? vec3( 0, 0, 1 ) : normalize( vViewPosition );
vec3 geometryClearcoatNormal = vec3( 0.0 );
#ifdef USE_CLEARCOAT
	geometryClearcoatNormal = clearcoatNormal;
#endif
#ifdef USE_IRIDESCENCE
	float dotNVi = saturate( dot( normal, geometryViewDir ) );
	if ( material.iridescenceThickness == 0.0 ) {
		material.iridescence = 0.0;
	} else {
		material.iridescence = saturate( material.iridescence );
	}
	if ( material.iridescence > 0.0 ) {
		material.iridescenceFresnel = evalIridescence( 1.0, material.iridescenceIOR, dotNVi, material.iridescenceThickness, material.specularColor );
		material.iridescenceF0 = Schlick_to_F0( material.iridescenceFresnel, 1.0, dotNVi );
	}
#endif
IncidentLight directLight;
#if ( NUM_POINT_LIGHTS > 0 ) && defined( RE_Direct )
	PointLight pointLight;
	#if defined( USE_SHADOWMAP ) && NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHTS; i ++ ) {
		pointLight = pointLights[ i ];
		getPointLightInfo( pointLight, geometryPosition, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_POINT_LIGHT_SHADOWS )
		pointLightShadow = pointLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getPointShadow( pointShadowMap[ i ], pointLightShadow.shadowMapSize, pointLightShadow.shadowIntensity, pointLightShadow.shadowBias, pointLightShadow.shadowRadius, vPointShadowCoord[ i ], pointLightShadow.shadowCameraNear, pointLightShadow.shadowCameraFar ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_SPOT_LIGHTS > 0 ) && defined( RE_Direct )
	SpotLight spotLight;
	vec4 spotColor;
	vec3 spotLightCoord;
	bool inSpotLightMap;
	#if defined( USE_SHADOWMAP ) && NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHTS; i ++ ) {
		spotLight = spotLights[ i ];
		getSpotLightInfo( spotLight, geometryPosition, directLight );
		#if ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#define SPOT_LIGHT_MAP_INDEX UNROLLED_LOOP_INDEX
		#elif ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		#define SPOT_LIGHT_MAP_INDEX NUM_SPOT_LIGHT_MAPS
		#else
		#define SPOT_LIGHT_MAP_INDEX ( UNROLLED_LOOP_INDEX - NUM_SPOT_LIGHT_SHADOWS + NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#endif
		#if ( SPOT_LIGHT_MAP_INDEX < NUM_SPOT_LIGHT_MAPS )
			spotLightCoord = vSpotLightCoord[ i ].xyz / vSpotLightCoord[ i ].w;
			inSpotLightMap = all( lessThan( abs( spotLightCoord * 2. - 1. ), vec3( 1.0 ) ) );
			spotColor = texture2D( spotLightMap[ SPOT_LIGHT_MAP_INDEX ], spotLightCoord.xy );
			directLight.color = inSpotLightMap ? directLight.color * spotColor.rgb : directLight.color;
		#endif
		#undef SPOT_LIGHT_MAP_INDEX
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		spotLightShadow = spotLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( spotShadowMap[ i ], spotLightShadow.shadowMapSize, spotLightShadow.shadowIntensity, spotLightShadow.shadowBias, spotLightShadow.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_DIR_LIGHTS > 0 ) && defined( RE_Direct )
	DirectionalLight directionalLight;
	#if defined( USE_SHADOWMAP ) && NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHTS; i ++ ) {
		directionalLight = directionalLights[ i ];
		getDirectionalLightInfo( directionalLight, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_DIR_LIGHT_SHADOWS )
		directionalLightShadow = directionalLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( directionalShadowMap[ i ], directionalLightShadow.shadowMapSize, directionalLightShadow.shadowIntensity, directionalLightShadow.shadowBias, directionalLightShadow.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_RECT_AREA_LIGHTS > 0 ) && defined( RE_Direct_RectArea )
	RectAreaLight rectAreaLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_RECT_AREA_LIGHTS; i ++ ) {
		rectAreaLight = rectAreaLights[ i ];
		RE_Direct_RectArea( rectAreaLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if defined( RE_IndirectDiffuse )
	vec3 iblIrradiance = vec3( 0.0 );
	vec3 irradiance = getAmbientLightIrradiance( ambientLightColor );
	#if defined( USE_LIGHT_PROBES )
		irradiance += getLightProbeIrradiance( lightProbe, geometryNormal );
	#endif
	#if ( NUM_HEMI_LIGHTS > 0 )
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_HEMI_LIGHTS; i ++ ) {
			irradiance += getHemisphereLightIrradiance( hemisphereLights[ i ], geometryNormal );
		}
		#pragma unroll_loop_end
	#endif
#endif
#if defined( RE_IndirectSpecular )
	vec3 radiance = vec3( 0.0 );
	vec3 clearcoatRadiance = vec3( 0.0 );
#endif`,R0=`#if defined( RE_IndirectDiffuse )
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		vec3 lightMapIrradiance = lightMapTexel.rgb * lightMapIntensity;
		irradiance += lightMapIrradiance;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD ) && defined( ENVMAP_TYPE_CUBE_UV )
		iblIrradiance += getIBLIrradiance( geometryNormal );
	#endif
#endif
#if defined( USE_ENVMAP ) && defined( RE_IndirectSpecular )
	#ifdef USE_ANISOTROPY
		radiance += getIBLAnisotropyRadiance( geometryViewDir, geometryNormal, material.roughness, material.anisotropyB, material.anisotropy );
	#else
		radiance += getIBLRadiance( geometryViewDir, geometryNormal, material.roughness );
	#endif
	#ifdef USE_CLEARCOAT
		clearcoatRadiance += getIBLRadiance( geometryViewDir, geometryClearcoatNormal, material.clearcoatRoughness );
	#endif
#endif`,C0=`#if defined( RE_IndirectDiffuse )
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,P0=`#if defined( USE_LOGDEPTHBUF )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,I0=`#if defined( USE_LOGDEPTHBUF )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,L0=`#ifdef USE_LOGDEPTHBUF
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,D0=`#ifdef USE_LOGDEPTHBUF
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,U0=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = sRGBTransferEOTF( sampledDiffuseColor );
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,N0=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,F0=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
	#if defined( USE_POINTS_UV )
		vec2 uv = vUv;
	#else
		vec2 uv = ( uvTransform * vec3( gl_PointCoord.x, 1.0 - gl_PointCoord.y, 1 ) ).xy;
	#endif
#endif
#ifdef USE_MAP
	diffuseColor *= texture2D( map, uv );
#endif
#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, uv ).g;
#endif`,O0=`#if defined( USE_POINTS_UV )
	varying vec2 vUv;
#else
	#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
		uniform mat3 uvTransform;
	#endif
#endif
#ifdef USE_MAP
	uniform sampler2D map;
#endif
#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,H0=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,B0=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,k0=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,z0=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,G0=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,V0=`#ifdef USE_MORPHTARGETS
	#ifndef USE_INSTANCING_MORPH
		uniform float morphTargetBaseInfluence;
		uniform float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	#endif
	uniform sampler2DArray morphTargetsTexture;
	uniform ivec2 morphTargetsTextureSize;
	vec4 getMorph( const in int vertexIndex, const in int morphTargetIndex, const in int offset ) {
		int texelIndex = vertexIndex * MORPHTARGETS_TEXTURE_STRIDE + offset;
		int y = texelIndex / morphTargetsTextureSize.x;
		int x = texelIndex - y * morphTargetsTextureSize.x;
		ivec3 morphUV = ivec3( x, y, morphTargetIndex );
		return texelFetch( morphTargetsTexture, morphUV, 0 );
	}
#endif`,W0=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,X0=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
#ifdef FLAT_SHADED
	vec3 fdx = dFdx( vViewPosition );
	vec3 fdy = dFdy( vViewPosition );
	vec3 normal = normalize( cross( fdx, fdy ) );
#else
	vec3 normal = normalize( vNormal );
	#ifdef DOUBLE_SIDED
		normal *= faceDirection;
	#endif
#endif
#if defined( USE_NORMALMAP_TANGENTSPACE ) || defined( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY )
	#ifdef USE_TANGENT
		mat3 tbn = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn = getTangentFrame( - vViewPosition, normal,
		#if defined( USE_NORMALMAP )
			vNormalMapUv
		#elif defined( USE_CLEARCOAT_NORMALMAP )
			vClearcoatNormalMapUv
		#else
			vUv
		#endif
		);
	#endif
	#if defined( DOUBLE_SIDED ) && ! defined( FLAT_SHADED )
		tbn[0] *= faceDirection;
		tbn[1] *= faceDirection;
	#endif
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	#ifdef USE_TANGENT
		mat3 tbn2 = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn2 = getTangentFrame( - vViewPosition, normal, vClearcoatNormalMapUv );
	#endif
	#if defined( DOUBLE_SIDED ) && ! defined( FLAT_SHADED )
		tbn2[0] *= faceDirection;
		tbn2[1] *= faceDirection;
	#endif
#endif
vec3 nonPerturbedNormal = normal;`,q0=`#ifdef USE_NORMALMAP_OBJECTSPACE
	normal = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	#ifdef FLIP_SIDED
		normal = - normal;
	#endif
	#ifdef DOUBLE_SIDED
		normal = normal * faceDirection;
	#endif
	normal = normalize( normalMatrix * normal );
#elif defined( USE_NORMALMAP_TANGENTSPACE )
	vec3 mapN = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	mapN.xy *= normalScale;
	normal = normalize( tbn * mapN );
#elif defined( USE_BUMPMAP )
	normal = perturbNormalArb( - vViewPosition, normal, dHdxy_fwd(), faceDirection );
#endif`,Y0=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,$0=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,Z0=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
	#endif
#endif`,J0=`#ifdef USE_NORMALMAP
	uniform sampler2D normalMap;
	uniform vec2 normalScale;
#endif
#ifdef USE_NORMALMAP_OBJECTSPACE
	uniform mat3 normalMatrix;
#endif
#if ! defined ( USE_TANGENT ) && ( defined ( USE_NORMALMAP_TANGENTSPACE ) || defined ( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY ) )
	mat3 getTangentFrame( vec3 eye_pos, vec3 surf_norm, vec2 uv ) {
		vec3 q0 = dFdx( eye_pos.xyz );
		vec3 q1 = dFdy( eye_pos.xyz );
		vec2 st0 = dFdx( uv.st );
		vec2 st1 = dFdy( uv.st );
		vec3 N = surf_norm;
		vec3 q1perp = cross( q1, N );
		vec3 q0perp = cross( N, q0 );
		vec3 T = q1perp * st0.x + q0perp * st1.x;
		vec3 B = q1perp * st0.y + q0perp * st1.y;
		float det = max( dot( T, T ), dot( B, B ) );
		float scale = ( det == 0.0 ) ? 0.0 : inversesqrt( det );
		return mat3( T * scale, B * scale, N );
	}
#endif`,K0=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,Q0=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,j0=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,tg=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,eg=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,ng=`vec3 packNormalToRGB( const in vec3 normal ) {
	return normalize( normal ) * 0.5 + 0.5;
}
vec3 unpackRGBToNormal( const in vec3 rgb ) {
	return 2.0 * rgb.xyz - 1.0;
}
const float PackUpscale = 256. / 255.;const float UnpackDownscale = 255. / 256.;const float ShiftRight8 = 1. / 256.;
const float Inv255 = 1. / 255.;
const vec4 PackFactors = vec4( 1.0, 256.0, 256.0 * 256.0, 256.0 * 256.0 * 256.0 );
const vec2 UnpackFactors2 = vec2( UnpackDownscale, 1.0 / PackFactors.g );
const vec3 UnpackFactors3 = vec3( UnpackDownscale / PackFactors.rg, 1.0 / PackFactors.b );
const vec4 UnpackFactors4 = vec4( UnpackDownscale / PackFactors.rgb, 1.0 / PackFactors.a );
vec4 packDepthToRGBA( const in float v ) {
	if( v <= 0.0 )
		return vec4( 0., 0., 0., 0. );
	if( v >= 1.0 )
		return vec4( 1., 1., 1., 1. );
	float vuf;
	float af = modf( v * PackFactors.a, vuf );
	float bf = modf( vuf * ShiftRight8, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec4( vuf * Inv255, gf * PackUpscale, bf * PackUpscale, af );
}
vec3 packDepthToRGB( const in float v ) {
	if( v <= 0.0 )
		return vec3( 0., 0., 0. );
	if( v >= 1.0 )
		return vec3( 1., 1., 1. );
	float vuf;
	float bf = modf( v * PackFactors.b, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec3( vuf * Inv255, gf * PackUpscale, bf );
}
vec2 packDepthToRG( const in float v ) {
	if( v <= 0.0 )
		return vec2( 0., 0. );
	if( v >= 1.0 )
		return vec2( 1., 1. );
	float vuf;
	float gf = modf( v * 256., vuf );
	return vec2( vuf * Inv255, gf );
}
float unpackRGBAToDepth( const in vec4 v ) {
	return dot( v, UnpackFactors4 );
}
float unpackRGBToDepth( const in vec3 v ) {
	return dot( v, UnpackFactors3 );
}
float unpackRGToDepth( const in vec2 v ) {
	return v.r * UnpackFactors2.r + v.g * UnpackFactors2.g;
}
vec4 pack2HalfToRGBA( const in vec2 v ) {
	vec4 r = vec4( v.x, fract( v.x * 255.0 ), v.y, fract( v.y * 255.0 ) );
	return vec4( r.x - r.y / 255.0, r.y, r.z - r.w / 255.0, r.w );
}
vec2 unpackRGBATo2Half( const in vec4 v ) {
	return vec2( v.x + ( v.y / 255.0 ), v.z + ( v.w / 255.0 ) );
}
float viewZToOrthographicDepth( const in float viewZ, const in float near, const in float far ) {
	return ( viewZ + near ) / ( near - far );
}
float orthographicDepthToViewZ( const in float depth, const in float near, const in float far ) {
	return depth * ( near - far ) - near;
}
float viewZToPerspectiveDepth( const in float viewZ, const in float near, const in float far ) {
	return ( ( near + viewZ ) * far ) / ( ( far - near ) * viewZ );
}
float perspectiveDepthToViewZ( const in float depth, const in float near, const in float far ) {
	return ( near * far ) / ( ( far - near ) * depth - far );
}`,ig=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,sg=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,rg=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,og=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,ag=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,lg=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,cg=`#if NUM_SPOT_LIGHT_COORDS > 0
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#if NUM_SPOT_LIGHT_MAPS > 0
	uniform sampler2D spotLightMap[ NUM_SPOT_LIGHT_MAPS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform sampler2D directionalShadowMap[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		uniform sampler2D spotShadowMap[ NUM_SPOT_LIGHT_SHADOWS ];
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform sampler2D pointShadowMap[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
	float texture2DCompare( sampler2D depths, vec2 uv, float compare ) {
		return step( compare, unpackRGBAToDepth( texture2D( depths, uv ) ) );
	}
	vec2 texture2DDistribution( sampler2D shadow, vec2 uv ) {
		return unpackRGBATo2Half( texture2D( shadow, uv ) );
	}
	float VSMShadow (sampler2D shadow, vec2 uv, float compare ){
		float occlusion = 1.0;
		vec2 distribution = texture2DDistribution( shadow, uv );
		float hard_shadow = step( compare , distribution.x );
		if (hard_shadow != 1.0 ) {
			float distance = compare - distribution.x ;
			float variance = max( 0.00000, distribution.y * distribution.y );
			float softness_probability = variance / (variance + distance * distance );			softness_probability = clamp( ( softness_probability - 0.3 ) / ( 0.95 - 0.3 ), 0.0, 1.0 );			occlusion = clamp( max( hard_shadow, softness_probability ), 0.0, 1.0 );
		}
		return occlusion;
	}
	float getShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord ) {
		float shadow = 1.0;
		shadowCoord.xyz /= shadowCoord.w;
		shadowCoord.z += shadowBias;
		bool inFrustum = shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0;
		bool frustumTest = inFrustum && shadowCoord.z <= 1.0;
		if ( frustumTest ) {
		#if defined( SHADOWMAP_TYPE_PCF )
			vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
			float dx0 = - texelSize.x * shadowRadius;
			float dy0 = - texelSize.y * shadowRadius;
			float dx1 = + texelSize.x * shadowRadius;
			float dy1 = + texelSize.y * shadowRadius;
			float dx2 = dx0 / 2.0;
			float dy2 = dy0 / 2.0;
			float dx3 = dx1 / 2.0;
			float dy3 = dy1 / 2.0;
			shadow = (
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy, shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, dy1 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy1 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, dy1 ), shadowCoord.z )
			) * ( 1.0 / 17.0 );
		#elif defined( SHADOWMAP_TYPE_PCF_SOFT )
			vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
			float dx = texelSize.x;
			float dy = texelSize.y;
			vec2 uv = shadowCoord.xy;
			vec2 f = fract( uv * shadowMapSize + 0.5 );
			uv -= f * texelSize;
			shadow = (
				texture2DCompare( shadowMap, uv, shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + vec2( dx, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + vec2( 0.0, dy ), shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + texelSize, shadowCoord.z ) +
				mix( texture2DCompare( shadowMap, uv + vec2( -dx, 0.0 ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, 0.0 ), shadowCoord.z ),
					 f.x ) +
				mix( texture2DCompare( shadowMap, uv + vec2( -dx, dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, dy ), shadowCoord.z ),
					 f.x ) +
				mix( texture2DCompare( shadowMap, uv + vec2( 0.0, -dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 0.0, 2.0 * dy ), shadowCoord.z ),
					 f.y ) +
				mix( texture2DCompare( shadowMap, uv + vec2( dx, -dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( dx, 2.0 * dy ), shadowCoord.z ),
					 f.y ) +
				mix( mix( texture2DCompare( shadowMap, uv + vec2( -dx, -dy ), shadowCoord.z ),
						  texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, -dy ), shadowCoord.z ),
						  f.x ),
					 mix( texture2DCompare( shadowMap, uv + vec2( -dx, 2.0 * dy ), shadowCoord.z ),
						  texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, 2.0 * dy ), shadowCoord.z ),
						  f.x ),
					 f.y )
			) * ( 1.0 / 9.0 );
		#elif defined( SHADOWMAP_TYPE_VSM )
			shadow = VSMShadow( shadowMap, shadowCoord.xy, shadowCoord.z );
		#else
			shadow = texture2DCompare( shadowMap, shadowCoord.xy, shadowCoord.z );
		#endif
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
	vec2 cubeToUV( vec3 v, float texelSizeY ) {
		vec3 absV = abs( v );
		float scaleToCube = 1.0 / max( absV.x, max( absV.y, absV.z ) );
		absV *= scaleToCube;
		v *= scaleToCube * ( 1.0 - 2.0 * texelSizeY );
		vec2 planar = v.xy;
		float almostATexel = 1.5 * texelSizeY;
		float almostOne = 1.0 - almostATexel;
		if ( absV.z >= almostOne ) {
			if ( v.z > 0.0 )
				planar.x = 4.0 - v.x;
		} else if ( absV.x >= almostOne ) {
			float signX = sign( v.x );
			planar.x = v.z * signX + 2.0 * signX;
		} else if ( absV.y >= almostOne ) {
			float signY = sign( v.y );
			planar.x = v.x + 2.0 * signY + 2.0;
			planar.y = v.z * signY - 2.0;
		}
		return vec2( 0.125, 0.25 ) * planar + vec2( 0.375, 0.75 );
	}
	float getPointShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord, float shadowCameraNear, float shadowCameraFar ) {
		float shadow = 1.0;
		vec3 lightToPosition = shadowCoord.xyz;
		
		float lightToPositionLength = length( lightToPosition );
		if ( lightToPositionLength - shadowCameraFar <= 0.0 && lightToPositionLength - shadowCameraNear >= 0.0 ) {
			float dp = ( lightToPositionLength - shadowCameraNear ) / ( shadowCameraFar - shadowCameraNear );			dp += shadowBias;
			vec3 bd3D = normalize( lightToPosition );
			vec2 texelSize = vec2( 1.0 ) / ( shadowMapSize * vec2( 4.0, 2.0 ) );
			#if defined( SHADOWMAP_TYPE_PCF ) || defined( SHADOWMAP_TYPE_PCF_SOFT ) || defined( SHADOWMAP_TYPE_VSM )
				vec2 offset = vec2( - 1, 1 ) * shadowRadius * texelSize.y;
				shadow = (
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xyy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yyy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xyx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yyx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xxy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yxy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xxx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yxx, texelSize.y ), dp )
				) * ( 1.0 / 9.0 );
			#else
				shadow = texture2DCompare( shadowMap, cubeToUV( bd3D, texelSize.y ), dp );
			#endif
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
#endif`,hg=`#if NUM_SPOT_LIGHT_COORDS > 0
	uniform mat4 spotLightMatrix[ NUM_SPOT_LIGHT_COORDS ];
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform mat4 directionalShadowMatrix[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform mat4 pointShadowMatrix[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
#endif`,ug=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
	vec3 shadowWorldNormal = inverseTransformDirection( transformedNormal, viewMatrix );
	vec4 shadowWorldPosition;
#endif
#if defined( USE_SHADOWMAP )
	#if NUM_DIR_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * directionalLightShadows[ i ].shadowNormalBias, 0 );
			vDirectionalShadowCoord[ i ] = directionalShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * pointLightShadows[ i ].shadowNormalBias, 0 );
			vPointShadowCoord[ i ] = pointShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
#endif
#if NUM_SPOT_LIGHT_COORDS > 0
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_COORDS; i ++ ) {
		shadowWorldPosition = worldPosition;
		#if ( defined( USE_SHADOWMAP ) && UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
			shadowWorldPosition.xyz += shadowWorldNormal * spotLightShadows[ i ].shadowNormalBias;
		#endif
		vSpotLightCoord[ i ] = spotLightMatrix[ i ] * shadowWorldPosition;
	}
	#pragma unroll_loop_end
#endif`,dg=`float getShadowMask() {
	float shadow = 1.0;
	#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
		directionalLight = directionalLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( directionalShadowMap[ i ], directionalLight.shadowMapSize, directionalLight.shadowIntensity, directionalLight.shadowBias, directionalLight.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_SHADOWS; i ++ ) {
		spotLight = spotLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( spotShadowMap[ i ], spotLight.shadowMapSize, spotLight.shadowIntensity, spotLight.shadowBias, spotLight.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
		pointLight = pointLightShadows[ i ];
		shadow *= receiveShadow ? getPointShadow( pointShadowMap[ i ], pointLight.shadowMapSize, pointLight.shadowIntensity, pointLight.shadowBias, pointLight.shadowRadius, vPointShadowCoord[ i ], pointLight.shadowCameraNear, pointLight.shadowCameraFar ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#endif
	return shadow;
}`,fg=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,pg=`#ifdef USE_SKINNING
	uniform mat4 bindMatrix;
	uniform mat4 bindMatrixInverse;
	uniform highp sampler2D boneTexture;
	mat4 getBoneMatrix( const in float i ) {
		int size = textureSize( boneTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( boneTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( boneTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( boneTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( boneTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
#endif`,mg=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,gg=`#ifdef USE_SKINNING
	mat4 skinMatrix = mat4( 0.0 );
	skinMatrix += skinWeight.x * boneMatX;
	skinMatrix += skinWeight.y * boneMatY;
	skinMatrix += skinWeight.z * boneMatZ;
	skinMatrix += skinWeight.w * boneMatW;
	skinMatrix = bindMatrixInverse * skinMatrix * bindMatrix;
	objectNormal = vec4( skinMatrix * vec4( objectNormal, 0.0 ) ).xyz;
	#ifdef USE_TANGENT
		objectTangent = vec4( skinMatrix * vec4( objectTangent, 0.0 ) ).xyz;
	#endif
#endif`,xg=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,yg=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,_g=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,vg=`#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
uniform float toneMappingExposure;
vec3 LinearToneMapping( vec3 color ) {
	return saturate( toneMappingExposure * color );
}
vec3 ReinhardToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	return saturate( color / ( vec3( 1.0 ) + color ) );
}
vec3 CineonToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	color = max( vec3( 0.0 ), color - 0.004 );
	return pow( ( color * ( 6.2 * color + 0.5 ) ) / ( color * ( 6.2 * color + 1.7 ) + 0.06 ), vec3( 2.2 ) );
}
vec3 RRTAndODTFit( vec3 v ) {
	vec3 a = v * ( v + 0.0245786 ) - 0.000090537;
	vec3 b = v * ( 0.983729 * v + 0.4329510 ) + 0.238081;
	return a / b;
}
vec3 ACESFilmicToneMapping( vec3 color ) {
	const mat3 ACESInputMat = mat3(
		vec3( 0.59719, 0.07600, 0.02840 ),		vec3( 0.35458, 0.90834, 0.13383 ),
		vec3( 0.04823, 0.01566, 0.83777 )
	);
	const mat3 ACESOutputMat = mat3(
		vec3(  1.60475, -0.10208, -0.00327 ),		vec3( -0.53108,  1.10813, -0.07276 ),
		vec3( -0.07367, -0.00605,  1.07602 )
	);
	color *= toneMappingExposure / 0.6;
	color = ACESInputMat * color;
	color = RRTAndODTFit( color );
	color = ACESOutputMat * color;
	return saturate( color );
}
const mat3 LINEAR_REC2020_TO_LINEAR_SRGB = mat3(
	vec3( 1.6605, - 0.1246, - 0.0182 ),
	vec3( - 0.5876, 1.1329, - 0.1006 ),
	vec3( - 0.0728, - 0.0083, 1.1187 )
);
const mat3 LINEAR_SRGB_TO_LINEAR_REC2020 = mat3(
	vec3( 0.6274, 0.0691, 0.0164 ),
	vec3( 0.3293, 0.9195, 0.0880 ),
	vec3( 0.0433, 0.0113, 0.8956 )
);
vec3 agxDefaultContrastApprox( vec3 x ) {
	vec3 x2 = x * x;
	vec3 x4 = x2 * x2;
	return + 15.5 * x4 * x2
		- 40.14 * x4 * x
		+ 31.96 * x4
		- 6.868 * x2 * x
		+ 0.4298 * x2
		+ 0.1191 * x
		- 0.00232;
}
vec3 AgXToneMapping( vec3 color ) {
	const mat3 AgXInsetMatrix = mat3(
		vec3( 0.856627153315983, 0.137318972929847, 0.11189821299995 ),
		vec3( 0.0951212405381588, 0.761241990602591, 0.0767994186031903 ),
		vec3( 0.0482516061458583, 0.101439036467562, 0.811302368396859 )
	);
	const mat3 AgXOutsetMatrix = mat3(
		vec3( 1.1271005818144368, - 0.1413297634984383, - 0.14132976349843826 ),
		vec3( - 0.11060664309660323, 1.157823702216272, - 0.11060664309660294 ),
		vec3( - 0.016493938717834573, - 0.016493938717834257, 1.2519364065950405 )
	);
	const float AgxMinEv = - 12.47393;	const float AgxMaxEv = 4.026069;
	color *= toneMappingExposure;
	color = LINEAR_SRGB_TO_LINEAR_REC2020 * color;
	color = AgXInsetMatrix * color;
	color = max( color, 1e-10 );	color = log2( color );
	color = ( color - AgxMinEv ) / ( AgxMaxEv - AgxMinEv );
	color = clamp( color, 0.0, 1.0 );
	color = agxDefaultContrastApprox( color );
	color = AgXOutsetMatrix * color;
	color = pow( max( vec3( 0.0 ), color ), vec3( 2.2 ) );
	color = LINEAR_REC2020_TO_LINEAR_SRGB * color;
	color = clamp( color, 0.0, 1.0 );
	return color;
}
vec3 NeutralToneMapping( vec3 color ) {
	const float StartCompression = 0.8 - 0.04;
	const float Desaturation = 0.15;
	color *= toneMappingExposure;
	float x = min( color.r, min( color.g, color.b ) );
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max( color.r, max( color.g, color.b ) );
	if ( peak < StartCompression ) return color;
	float d = 1. - StartCompression;
	float newPeak = 1. - d * d / ( peak + d - StartCompression );
	color *= newPeak / peak;
	float g = 1. - 1. / ( Desaturation * ( peak - newPeak ) + 1. );
	return mix( color, vec3( newPeak ), g );
}
vec3 CustomToneMapping( vec3 color ) { return color; }`,Mg=`#ifdef USE_TRANSMISSION
	material.transmission = transmission;
	material.transmissionAlpha = 1.0;
	material.thickness = thickness;
	material.attenuationDistance = attenuationDistance;
	material.attenuationColor = attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		material.transmission *= texture2D( transmissionMap, vTransmissionMapUv ).r;
	#endif
	#ifdef USE_THICKNESSMAP
		material.thickness *= texture2D( thicknessMap, vThicknessMapUv ).g;
	#endif
	vec3 pos = vWorldPosition;
	vec3 v = normalize( cameraPosition - pos );
	vec3 n = inverseTransformDirection( normal, viewMatrix );
	vec4 transmitted = getIBLVolumeRefraction(
		n, v, material.roughness, material.diffuseColor, material.specularColor, material.specularF90,
		pos, modelMatrix, viewMatrix, projectionMatrix, material.dispersion, material.ior, material.thickness,
		material.attenuationColor, material.attenuationDistance );
	material.transmissionAlpha = mix( material.transmissionAlpha, transmitted.a, material.transmission );
	totalDiffuse = mix( totalDiffuse, transmitted.rgb, material.transmission );
#endif`,Eg=`#ifdef USE_TRANSMISSION
	uniform float transmission;
	uniform float thickness;
	uniform float attenuationDistance;
	uniform vec3 attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		uniform sampler2D transmissionMap;
	#endif
	#ifdef USE_THICKNESSMAP
		uniform sampler2D thicknessMap;
	#endif
	uniform vec2 transmissionSamplerSize;
	uniform sampler2D transmissionSamplerMap;
	uniform mat4 modelMatrix;
	uniform mat4 projectionMatrix;
	varying vec3 vWorldPosition;
	float w0( float a ) {
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - a + 3.0 ) - 3.0 ) + 1.0 );
	}
	float w1( float a ) {
		return ( 1.0 / 6.0 ) * ( a *  a * ( 3.0 * a - 6.0 ) + 4.0 );
	}
	float w2( float a ){
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - 3.0 * a + 3.0 ) + 3.0 ) + 1.0 );
	}
	float w3( float a ) {
		return ( 1.0 / 6.0 ) * ( a * a * a );
	}
	float g0( float a ) {
		return w0( a ) + w1( a );
	}
	float g1( float a ) {
		return w2( a ) + w3( a );
	}
	float h0( float a ) {
		return - 1.0 + w1( a ) / ( w0( a ) + w1( a ) );
	}
	float h1( float a ) {
		return 1.0 + w3( a ) / ( w2( a ) + w3( a ) );
	}
	vec4 bicubic( sampler2D tex, vec2 uv, vec4 texelSize, float lod ) {
		uv = uv * texelSize.zw + 0.5;
		vec2 iuv = floor( uv );
		vec2 fuv = fract( uv );
		float g0x = g0( fuv.x );
		float g1x = g1( fuv.x );
		float h0x = h0( fuv.x );
		float h1x = h1( fuv.x );
		float h0y = h0( fuv.y );
		float h1y = h1( fuv.y );
		vec2 p0 = ( vec2( iuv.x + h0x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p1 = ( vec2( iuv.x + h1x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p2 = ( vec2( iuv.x + h0x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		vec2 p3 = ( vec2( iuv.x + h1x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		return g0( fuv.y ) * ( g0x * textureLod( tex, p0, lod ) + g1x * textureLod( tex, p1, lod ) ) +
			g1( fuv.y ) * ( g0x * textureLod( tex, p2, lod ) + g1x * textureLod( tex, p3, lod ) );
	}
	vec4 textureBicubic( sampler2D sampler, vec2 uv, float lod ) {
		vec2 fLodSize = vec2( textureSize( sampler, int( lod ) ) );
		vec2 cLodSize = vec2( textureSize( sampler, int( lod + 1.0 ) ) );
		vec2 fLodSizeInv = 1.0 / fLodSize;
		vec2 cLodSizeInv = 1.0 / cLodSize;
		vec4 fSample = bicubic( sampler, uv, vec4( fLodSizeInv, fLodSize ), floor( lod ) );
		vec4 cSample = bicubic( sampler, uv, vec4( cLodSizeInv, cLodSize ), ceil( lod ) );
		return mix( fSample, cSample, fract( lod ) );
	}
	vec3 getVolumeTransmissionRay( const in vec3 n, const in vec3 v, const in float thickness, const in float ior, const in mat4 modelMatrix ) {
		vec3 refractionVector = refract( - v, normalize( n ), 1.0 / ior );
		vec3 modelScale;
		modelScale.x = length( vec3( modelMatrix[ 0 ].xyz ) );
		modelScale.y = length( vec3( modelMatrix[ 1 ].xyz ) );
		modelScale.z = length( vec3( modelMatrix[ 2 ].xyz ) );
		return normalize( refractionVector ) * thickness * modelScale;
	}
	float applyIorToRoughness( const in float roughness, const in float ior ) {
		return roughness * clamp( ior * 2.0 - 2.0, 0.0, 1.0 );
	}
	vec4 getTransmissionSample( const in vec2 fragCoord, const in float roughness, const in float ior ) {
		float lod = log2( transmissionSamplerSize.x ) * applyIorToRoughness( roughness, ior );
		return textureBicubic( transmissionSamplerMap, fragCoord.xy, lod );
	}
	vec3 volumeAttenuation( const in float transmissionDistance, const in vec3 attenuationColor, const in float attenuationDistance ) {
		if ( isinf( attenuationDistance ) ) {
			return vec3( 1.0 );
		} else {
			vec3 attenuationCoefficient = -log( attenuationColor ) / attenuationDistance;
			vec3 transmittance = exp( - attenuationCoefficient * transmissionDistance );			return transmittance;
		}
	}
	vec4 getIBLVolumeRefraction( const in vec3 n, const in vec3 v, const in float roughness, const in vec3 diffuseColor,
		const in vec3 specularColor, const in float specularF90, const in vec3 position, const in mat4 modelMatrix,
		const in mat4 viewMatrix, const in mat4 projMatrix, const in float dispersion, const in float ior, const in float thickness,
		const in vec3 attenuationColor, const in float attenuationDistance ) {
		vec4 transmittedLight;
		vec3 transmittance;
		#ifdef USE_DISPERSION
			float halfSpread = ( ior - 1.0 ) * 0.025 * dispersion;
			vec3 iors = vec3( ior - halfSpread, ior, ior + halfSpread );
			for ( int i = 0; i < 3; i ++ ) {
				vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, iors[ i ], modelMatrix );
				vec3 refractedRayExit = position + transmissionRay;
		
				vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
				vec2 refractionCoords = ndcPos.xy / ndcPos.w;
				refractionCoords += 1.0;
				refractionCoords /= 2.0;
		
				vec4 transmissionSample = getTransmissionSample( refractionCoords, roughness, iors[ i ] );
				transmittedLight[ i ] = transmissionSample[ i ];
				transmittedLight.a += transmissionSample.a;
				transmittance[ i ] = diffuseColor[ i ] * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance )[ i ];
			}
			transmittedLight.a /= 3.0;
		
		#else
		
			vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, ior, modelMatrix );
			vec3 refractedRayExit = position + transmissionRay;
			vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
			vec2 refractionCoords = ndcPos.xy / ndcPos.w;
			refractionCoords += 1.0;
			refractionCoords /= 2.0;
			transmittedLight = getTransmissionSample( refractionCoords, roughness, ior );
			transmittance = diffuseColor * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance );
		
		#endif
		vec3 attenuatedColor = transmittance * transmittedLight.rgb;
		vec3 F = EnvironmentBRDF( n, v, specularColor, specularF90, roughness );
		float transmittanceFactor = ( transmittance.r + transmittance.g + transmittance.b ) / 3.0;
		return vec4( ( 1.0 - F ) * attenuatedColor, 1.0 - ( 1.0 - transmittedLight.a ) * transmittanceFactor );
	}
#endif`,Sg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_SPECULARMAP
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,wg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	uniform mat3 mapTransform;
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	uniform mat3 alphaMapTransform;
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	uniform mat3 lightMapTransform;
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	uniform mat3 aoMapTransform;
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	uniform mat3 bumpMapTransform;
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	uniform mat3 normalMapTransform;
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_DISPLACEMENTMAP
	uniform mat3 displacementMapTransform;
	varying vec2 vDisplacementMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	uniform mat3 emissiveMapTransform;
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	uniform mat3 metalnessMapTransform;
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	uniform mat3 roughnessMapTransform;
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	uniform mat3 anisotropyMapTransform;
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	uniform mat3 clearcoatMapTransform;
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform mat3 clearcoatNormalMapTransform;
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform mat3 clearcoatRoughnessMapTransform;
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	uniform mat3 sheenColorMapTransform;
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	uniform mat3 sheenRoughnessMapTransform;
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	uniform mat3 iridescenceMapTransform;
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform mat3 iridescenceThicknessMapTransform;
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SPECULARMAP
	uniform mat3 specularMapTransform;
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	uniform mat3 specularColorMapTransform;
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	uniform mat3 specularIntensityMapTransform;
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,Tg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	vUv = vec3( uv, 1 ).xy;
#endif
#ifdef USE_MAP
	vMapUv = ( mapTransform * vec3( MAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ALPHAMAP
	vAlphaMapUv = ( alphaMapTransform * vec3( ALPHAMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_LIGHTMAP
	vLightMapUv = ( lightMapTransform * vec3( LIGHTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_AOMAP
	vAoMapUv = ( aoMapTransform * vec3( AOMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_BUMPMAP
	vBumpMapUv = ( bumpMapTransform * vec3( BUMPMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_NORMALMAP
	vNormalMapUv = ( normalMapTransform * vec3( NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_DISPLACEMENTMAP
	vDisplacementMapUv = ( displacementMapTransform * vec3( DISPLACEMENTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_EMISSIVEMAP
	vEmissiveMapUv = ( emissiveMapTransform * vec3( EMISSIVEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_METALNESSMAP
	vMetalnessMapUv = ( metalnessMapTransform * vec3( METALNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ROUGHNESSMAP
	vRoughnessMapUv = ( roughnessMapTransform * vec3( ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ANISOTROPYMAP
	vAnisotropyMapUv = ( anisotropyMapTransform * vec3( ANISOTROPYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOATMAP
	vClearcoatMapUv = ( clearcoatMapTransform * vec3( CLEARCOATMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	vClearcoatNormalMapUv = ( clearcoatNormalMapTransform * vec3( CLEARCOAT_NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	vClearcoatRoughnessMapUv = ( clearcoatRoughnessMapTransform * vec3( CLEARCOAT_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCEMAP
	vIridescenceMapUv = ( iridescenceMapTransform * vec3( IRIDESCENCEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	vIridescenceThicknessMapUv = ( iridescenceThicknessMapTransform * vec3( IRIDESCENCE_THICKNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_COLORMAP
	vSheenColorMapUv = ( sheenColorMapTransform * vec3( SHEEN_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	vSheenRoughnessMapUv = ( sheenRoughnessMapTransform * vec3( SHEEN_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULARMAP
	vSpecularMapUv = ( specularMapTransform * vec3( SPECULARMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_COLORMAP
	vSpecularColorMapUv = ( specularColorMapTransform * vec3( SPECULAR_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	vSpecularIntensityMapUv = ( specularIntensityMapTransform * vec3( SPECULAR_INTENSITYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_TRANSMISSIONMAP
	vTransmissionMapUv = ( transmissionMapTransform * vec3( TRANSMISSIONMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_THICKNESSMAP
	vThicknessMapUv = ( thicknessMapTransform * vec3( THICKNESSMAP_UV, 1 ) ).xy;
#endif`,bg=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`,Ag=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,Rg=`uniform sampler2D t2D;
uniform float backgroundIntensity;
varying vec2 vUv;
void main() {
	vec4 texColor = texture2D( t2D, vUv );
	#ifdef DECODE_VIDEO_TEXTURE
		texColor = vec4( mix( pow( texColor.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), texColor.rgb * 0.0773993808, vec3( lessThanEqual( texColor.rgb, vec3( 0.04045 ) ) ) ), texColor.w );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Cg=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Pg=`#ifdef ENVMAP_TYPE_CUBE
	uniform samplerCube envMap;
#elif defined( ENVMAP_TYPE_CUBE_UV )
	uniform sampler2D envMap;
#endif
uniform float flipEnvMap;
uniform float backgroundBlurriness;
uniform float backgroundIntensity;
uniform mat3 backgroundRotation;
varying vec3 vWorldDirection;
#include <cube_uv_reflection_fragment>
void main() {
	#ifdef ENVMAP_TYPE_CUBE
		vec4 texColor = textureCube( envMap, backgroundRotation * vec3( flipEnvMap * vWorldDirection.x, vWorldDirection.yz ) );
	#elif defined( ENVMAP_TYPE_CUBE_UV )
		vec4 texColor = textureCubeUV( envMap, backgroundRotation * vWorldDirection, backgroundBlurriness );
	#else
		vec4 texColor = vec4( 0.0, 0.0, 0.0, 1.0 );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Ig=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Lg=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Dg=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
varying vec2 vHighPrecisionZW;
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vHighPrecisionZW = gl_Position.zw;
}`,Ug=`#if DEPTH_PACKING == 3200
	uniform float opacity;
#endif
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
varying vec2 vHighPrecisionZW;
void main() {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#if DEPTH_PACKING == 3200
		diffuseColor.a = opacity;
	#endif
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <logdepthbuf_fragment>
	float fragCoordZ = 0.5 * vHighPrecisionZW[0] / vHighPrecisionZW[1] + 0.5;
	#if DEPTH_PACKING == 3200
		gl_FragColor = vec4( vec3( 1.0 - fragCoordZ ), opacity );
	#elif DEPTH_PACKING == 3201
		gl_FragColor = packDepthToRGBA( fragCoordZ );
	#elif DEPTH_PACKING == 3202
		gl_FragColor = vec4( packDepthToRGB( fragCoordZ ), 1.0 );
	#elif DEPTH_PACKING == 3203
		gl_FragColor = vec4( packDepthToRG( fragCoordZ ), 0.0, 1.0 );
	#endif
}`,Ng=`#define DISTANCE
varying vec3 vWorldPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <worldpos_vertex>
	#include <clipping_planes_vertex>
	vWorldPosition = worldPosition.xyz;
}`,Fg=`#define DISTANCE
uniform vec3 referencePosition;
uniform float nearDistance;
uniform float farDistance;
varying vec3 vWorldPosition;
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <clipping_planes_pars_fragment>
void main () {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	float dist = length( vWorldPosition - referencePosition );
	dist = ( dist - nearDistance ) / ( farDistance - nearDistance );
	dist = saturate( dist );
	gl_FragColor = packDepthToRGBA( dist );
}`,Og=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,Hg=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Bg=`uniform float scale;
attribute float lineDistance;
varying float vLineDistance;
#include <common>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	vLineDistance = scale * lineDistance;
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,kg=`uniform vec3 diffuse;
uniform float opacity;
uniform float dashSize;
uniform float totalSize;
varying float vLineDistance;
#include <common>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	if ( mod( vLineDistance, totalSize ) > dashSize ) {
		discard;
	}
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,zg=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#if defined ( USE_ENVMAP ) || defined ( USE_SKINNING )
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinbase_vertex>
		#include <skinnormal_vertex>
		#include <defaultnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <fog_vertex>
}`,Gg=`uniform vec3 diffuse;
uniform float opacity;
#ifndef FLAT_SHADED
	varying vec3 vNormal;
#endif
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		reflectedLight.indirectDiffuse += lightMapTexel.rgb * lightMapIntensity * RECIPROCAL_PI;
	#else
		reflectedLight.indirectDiffuse += vec3( 1.0 );
	#endif
	#include <aomap_fragment>
	reflectedLight.indirectDiffuse *= diffuseColor.rgb;
	vec3 outgoingLight = reflectedLight.indirectDiffuse;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,Vg=`#define LAMBERT
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,Wg=`#define LAMBERT
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_lambert_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_lambert_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,Xg=`#define MATCAP
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <displacementmap_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
	vViewPosition = - mvPosition.xyz;
}`,qg=`#define MATCAP
uniform vec3 diffuse;
uniform float opacity;
uniform sampler2D matcap;
varying vec3 vViewPosition;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	vec3 viewDir = normalize( vViewPosition );
	vec3 x = normalize( vec3( viewDir.z, 0.0, - viewDir.x ) );
	vec3 y = cross( viewDir, x );
	vec2 uv = vec2( dot( x, normal ), dot( y, normal ) ) * 0.495 + 0.5;
	#ifdef USE_MATCAP
		vec4 matcapColor = texture2D( matcap, uv );
	#else
		vec4 matcapColor = vec4( vec3( mix( 0.2, 0.8, uv.y ) ), 1.0 );
	#endif
	vec3 outgoingLight = diffuseColor.rgb * matcapColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,Yg=`#define NORMAL
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	vViewPosition = - mvPosition.xyz;
#endif
}`,$g=`#define NORMAL
uniform float opacity;
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <packing>
#include <uv_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( 0.0, 0.0, 0.0, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	gl_FragColor = vec4( packNormalToRGB( normal ), diffuseColor.a );
	#ifdef OPAQUE
		gl_FragColor.a = 1.0;
	#endif
}`,Zg=`#define PHONG
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,Jg=`#define PHONG
uniform vec3 diffuse;
uniform vec3 emissive;
uniform vec3 specular;
uniform float shininess;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_phong_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_phong_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + reflectedLight.directSpecular + reflectedLight.indirectSpecular + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,Kg=`#define STANDARD
varying vec3 vViewPosition;
#ifdef USE_TRANSMISSION
	varying vec3 vWorldPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
#ifdef USE_TRANSMISSION
	vWorldPosition = worldPosition.xyz;
#endif
}`,Qg=`#define STANDARD
#ifdef PHYSICAL
	#define IOR
	#define USE_SPECULAR
#endif
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float roughness;
uniform float metalness;
uniform float opacity;
#ifdef IOR
	uniform float ior;
#endif
#ifdef USE_SPECULAR
	uniform float specularIntensity;
	uniform vec3 specularColor;
	#ifdef USE_SPECULAR_COLORMAP
		uniform sampler2D specularColorMap;
	#endif
	#ifdef USE_SPECULAR_INTENSITYMAP
		uniform sampler2D specularIntensityMap;
	#endif
#endif
#ifdef USE_CLEARCOAT
	uniform float clearcoat;
	uniform float clearcoatRoughness;
#endif
#ifdef USE_DISPERSION
	uniform float dispersion;
#endif
#ifdef USE_IRIDESCENCE
	uniform float iridescence;
	uniform float iridescenceIOR;
	uniform float iridescenceThicknessMinimum;
	uniform float iridescenceThicknessMaximum;
#endif
#ifdef USE_SHEEN
	uniform vec3 sheenColor;
	uniform float sheenRoughness;
	#ifdef USE_SHEEN_COLORMAP
		uniform sampler2D sheenColorMap;
	#endif
	#ifdef USE_SHEEN_ROUGHNESSMAP
		uniform sampler2D sheenRoughnessMap;
	#endif
#endif
#ifdef USE_ANISOTROPY
	uniform vec2 anisotropyVector;
	#ifdef USE_ANISOTROPYMAP
		uniform sampler2D anisotropyMap;
	#endif
#endif
varying vec3 vViewPosition;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <iridescence_fragment>
#include <cube_uv_reflection_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_physical_pars_fragment>
#include <fog_pars_fragment>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_physical_pars_fragment>
#include <transmission_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <clearcoat_pars_fragment>
#include <iridescence_pars_fragment>
#include <roughnessmap_pars_fragment>
#include <metalnessmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <roughnessmap_fragment>
	#include <metalnessmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <clearcoat_normal_fragment_begin>
	#include <clearcoat_normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_physical_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 totalDiffuse = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse;
	vec3 totalSpecular = reflectedLight.directSpecular + reflectedLight.indirectSpecular;
	#include <transmission_fragment>
	vec3 outgoingLight = totalDiffuse + totalSpecular + totalEmissiveRadiance;
	#ifdef USE_SHEEN
		float sheenEnergyComp = 1.0 - 0.157 * max3( material.sheenColor );
		outgoingLight = outgoingLight * sheenEnergyComp + sheenSpecularDirect + sheenSpecularIndirect;
	#endif
	#ifdef USE_CLEARCOAT
		float dotNVcc = saturate( dot( geometryClearcoatNormal, geometryViewDir ) );
		vec3 Fcc = F_Schlick( material.clearcoatF0, material.clearcoatF90, dotNVcc );
		outgoingLight = outgoingLight * ( 1.0 - material.clearcoat * Fcc ) + ( clearcoatSpecularDirect + clearcoatSpecularIndirect ) * material.clearcoat;
	#endif
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,jg=`#define TOON
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,tx=`#define TOON
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <gradientmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_toon_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_toon_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,ex=`uniform float size;
uniform float scale;
#include <common>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
#ifdef USE_POINTS_UV
	varying vec2 vUv;
	uniform mat3 uvTransform;
#endif
void main() {
	#ifdef USE_POINTS_UV
		vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	#endif
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	gl_PointSize = size;
	#ifdef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) gl_PointSize *= ( scale / - mvPosition.z );
	#endif
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <fog_vertex>
}`,nx=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <color_pars_fragment>
#include <map_particle_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_particle_fragment>
	#include <color_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,ix=`#include <common>
#include <batching_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <shadowmap_pars_vertex>
void main() {
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,sx=`uniform vec3 color;
uniform float opacity;
#include <common>
#include <packing>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <logdepthbuf_pars_fragment>
#include <shadowmap_pars_fragment>
#include <shadowmask_pars_fragment>
void main() {
	#include <logdepthbuf_fragment>
	gl_FragColor = vec4( color, opacity * ( 1.0 - getShadowMask() ) );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,rx=`uniform float rotation;
uniform vec2 center;
#include <common>
#include <uv_pars_vertex>
#include <fog_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	vec4 mvPosition = modelViewMatrix[ 3 ];
	vec2 scale = vec2( length( modelMatrix[ 0 ].xyz ), length( modelMatrix[ 1 ].xyz ) );
	#ifndef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) scale *= - mvPosition.z;
	#endif
	vec2 alignedPosition = ( position.xy - ( center - vec2( 0.5 ) ) ) * scale;
	vec2 rotatedPosition;
	rotatedPosition.x = cos( rotation ) * alignedPosition.x - sin( rotation ) * alignedPosition.y;
	rotatedPosition.y = sin( rotation ) * alignedPosition.x + cos( rotation ) * alignedPosition.y;
	mvPosition.xy += rotatedPosition;
	gl_Position = projectionMatrix * mvPosition;
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,ox=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,ne={alphahash_fragment:Rm,alphahash_pars_fragment:Cm,alphamap_fragment:Pm,alphamap_pars_fragment:Im,alphatest_fragment:Lm,alphatest_pars_fragment:Dm,aomap_fragment:Um,aomap_pars_fragment:Nm,batching_pars_vertex:Fm,batching_vertex:Om,begin_vertex:Hm,beginnormal_vertex:Bm,bsdfs:km,iridescence_fragment:zm,bumpmap_pars_fragment:Gm,clipping_planes_fragment:Vm,clipping_planes_pars_fragment:Wm,clipping_planes_pars_vertex:Xm,clipping_planes_vertex:qm,color_fragment:Ym,color_pars_fragment:$m,color_pars_vertex:Zm,color_vertex:Jm,common:Km,cube_uv_reflection_fragment:Qm,defaultnormal_vertex:jm,displacementmap_pars_vertex:t0,displacementmap_vertex:e0,emissivemap_fragment:n0,emissivemap_pars_fragment:i0,colorspace_fragment:s0,colorspace_pars_fragment:r0,envmap_fragment:o0,envmap_common_pars_fragment:a0,envmap_pars_fragment:l0,envmap_pars_vertex:c0,envmap_physical_pars_fragment:v0,envmap_vertex:h0,fog_vertex:u0,fog_pars_vertex:d0,fog_fragment:f0,fog_pars_fragment:p0,gradientmap_pars_fragment:m0,lightmap_pars_fragment:g0,lights_lambert_fragment:x0,lights_lambert_pars_fragment:y0,lights_pars_begin:_0,lights_toon_fragment:M0,lights_toon_pars_fragment:E0,lights_phong_fragment:S0,lights_phong_pars_fragment:w0,lights_physical_fragment:T0,lights_physical_pars_fragment:b0,lights_fragment_begin:A0,lights_fragment_maps:R0,lights_fragment_end:C0,logdepthbuf_fragment:P0,logdepthbuf_pars_fragment:I0,logdepthbuf_pars_vertex:L0,logdepthbuf_vertex:D0,map_fragment:U0,map_pars_fragment:N0,map_particle_fragment:F0,map_particle_pars_fragment:O0,metalnessmap_fragment:H0,metalnessmap_pars_fragment:B0,morphinstance_vertex:k0,morphcolor_vertex:z0,morphnormal_vertex:G0,morphtarget_pars_vertex:V0,morphtarget_vertex:W0,normal_fragment_begin:X0,normal_fragment_maps:q0,normal_pars_fragment:Y0,normal_pars_vertex:$0,normal_vertex:Z0,normalmap_pars_fragment:J0,clearcoat_normal_fragment_begin:K0,clearcoat_normal_fragment_maps:Q0,clearcoat_pars_fragment:j0,iridescence_pars_fragment:tg,opaque_fragment:eg,packing:ng,premultiplied_alpha_fragment:ig,project_vertex:sg,dithering_fragment:rg,dithering_pars_fragment:og,roughnessmap_fragment:ag,roughnessmap_pars_fragment:lg,shadowmap_pars_fragment:cg,shadowmap_pars_vertex:hg,shadowmap_vertex:ug,shadowmask_pars_fragment:dg,skinbase_vertex:fg,skinning_pars_vertex:pg,skinning_vertex:mg,skinnormal_vertex:gg,specularmap_fragment:xg,specularmap_pars_fragment:yg,tonemapping_fragment:_g,tonemapping_pars_fragment:vg,transmission_fragment:Mg,transmission_pars_fragment:Eg,uv_pars_fragment:Sg,uv_pars_vertex:wg,uv_vertex:Tg,worldpos_vertex:bg,background_vert:Ag,background_frag:Rg,backgroundCube_vert:Cg,backgroundCube_frag:Pg,cube_vert:Ig,cube_frag:Lg,depth_vert:Dg,depth_frag:Ug,distanceRGBA_vert:Ng,distanceRGBA_frag:Fg,equirect_vert:Og,equirect_frag:Hg,linedashed_vert:Bg,linedashed_frag:kg,meshbasic_vert:zg,meshbasic_frag:Gg,meshlambert_vert:Vg,meshlambert_frag:Wg,meshmatcap_vert:Xg,meshmatcap_frag:qg,meshnormal_vert:Yg,meshnormal_frag:$g,meshphong_vert:Zg,meshphong_frag:Jg,meshphysical_vert:Kg,meshphysical_frag:Qg,meshtoon_vert:jg,meshtoon_frag:tx,points_vert:ex,points_frag:nx,shadow_vert:ix,shadow_frag:sx,sprite_vert:rx,sprite_frag:ox},_t={common:{diffuse:{value:new Ot(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new Qt},alphaMap:{value:null},alphaMapTransform:{value:new Qt},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new Qt}},envmap:{envMap:{value:null},envMapRotation:{value:new Qt},flipEnvMap:{value:-1},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new Qt}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new Qt}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new Qt},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new Qt},normalScale:{value:new at(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new Qt},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new Qt}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new Qt}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new Qt}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new Ot(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMap:{value:[]},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotShadowMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMap:{value:[]},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null}},points:{diffuse:{value:new Ot(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new Qt},alphaTest:{value:0},uvTransform:{value:new Qt}},sprite:{diffuse:{value:new Ot(16777215)},opacity:{value:1},center:{value:new at(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new Qt},alphaMap:{value:null},alphaMapTransform:{value:new Qt},alphaTest:{value:0}}},li={basic:{uniforms:cn([_t.common,_t.specularmap,_t.envmap,_t.aomap,_t.lightmap,_t.fog]),vertexShader:ne.meshbasic_vert,fragmentShader:ne.meshbasic_frag},lambert:{uniforms:cn([_t.common,_t.specularmap,_t.envmap,_t.aomap,_t.lightmap,_t.emissivemap,_t.bumpmap,_t.normalmap,_t.displacementmap,_t.fog,_t.lights,{emissive:{value:new Ot(0)}}]),vertexShader:ne.meshlambert_vert,fragmentShader:ne.meshlambert_frag},phong:{uniforms:cn([_t.common,_t.specularmap,_t.envmap,_t.aomap,_t.lightmap,_t.emissivemap,_t.bumpmap,_t.normalmap,_t.displacementmap,_t.fog,_t.lights,{emissive:{value:new Ot(0)},specular:{value:new Ot(1118481)},shininess:{value:30}}]),vertexShader:ne.meshphong_vert,fragmentShader:ne.meshphong_frag},standard:{uniforms:cn([_t.common,_t.envmap,_t.aomap,_t.lightmap,_t.emissivemap,_t.bumpmap,_t.normalmap,_t.displacementmap,_t.roughnessmap,_t.metalnessmap,_t.fog,_t.lights,{emissive:{value:new Ot(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:ne.meshphysical_vert,fragmentShader:ne.meshphysical_frag},toon:{uniforms:cn([_t.common,_t.aomap,_t.lightmap,_t.emissivemap,_t.bumpmap,_t.normalmap,_t.displacementmap,_t.gradientmap,_t.fog,_t.lights,{emissive:{value:new Ot(0)}}]),vertexShader:ne.meshtoon_vert,fragmentShader:ne.meshtoon_frag},matcap:{uniforms:cn([_t.common,_t.bumpmap,_t.normalmap,_t.displacementmap,_t.fog,{matcap:{value:null}}]),vertexShader:ne.meshmatcap_vert,fragmentShader:ne.meshmatcap_frag},points:{uniforms:cn([_t.points,_t.fog]),vertexShader:ne.points_vert,fragmentShader:ne.points_frag},dashed:{uniforms:cn([_t.common,_t.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:ne.linedashed_vert,fragmentShader:ne.linedashed_frag},depth:{uniforms:cn([_t.common,_t.displacementmap]),vertexShader:ne.depth_vert,fragmentShader:ne.depth_frag},normal:{uniforms:cn([_t.common,_t.bumpmap,_t.normalmap,_t.displacementmap,{opacity:{value:1}}]),vertexShader:ne.meshnormal_vert,fragmentShader:ne.meshnormal_frag},sprite:{uniforms:cn([_t.sprite,_t.fog]),vertexShader:ne.sprite_vert,fragmentShader:ne.sprite_frag},background:{uniforms:{uvTransform:{value:new Qt},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:ne.background_vert,fragmentShader:ne.background_frag},backgroundCube:{uniforms:{envMap:{value:null},flipEnvMap:{value:-1},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new Qt}},vertexShader:ne.backgroundCube_vert,fragmentShader:ne.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:ne.cube_vert,fragmentShader:ne.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:ne.equirect_vert,fragmentShader:ne.equirect_frag},distanceRGBA:{uniforms:cn([_t.common,_t.displacementmap,{referencePosition:{value:new O},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:ne.distanceRGBA_vert,fragmentShader:ne.distanceRGBA_frag},shadow:{uniforms:cn([_t.lights,_t.fog,{color:{value:new Ot(0)},opacity:{value:1}}]),vertexShader:ne.shadow_vert,fragmentShader:ne.shadow_frag}};li.physical={uniforms:cn([li.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new Qt},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new Qt},clearcoatNormalScale:{value:new at(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new Qt},dispersion:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new Qt},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new Qt},sheen:{value:0},sheenColor:{value:new Ot(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new Qt},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new Qt},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new Qt},transmissionSamplerSize:{value:new at},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new Qt},attenuationDistance:{value:0},attenuationColor:{value:new Ot(0)},specularColor:{value:new Ot(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new Qt},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new Qt},anisotropyVector:{value:new at},anisotropyMap:{value:null},anisotropyMapTransform:{value:new Qt}}]),vertexShader:ne.meshphysical_vert,fragmentShader:ne.meshphysical_frag};var Xl={r:0,b:0,g:0},Os=new Ln,ax=new be;function lx(n,t,e,i,s,r,a){let o=new Ot(0),l=r===!0?0:1,c,h,d=null,u=0,f=null;function x(E){let g=E.isScene===!0?E.background:null;return g&&g.isTexture&&(g=(E.backgroundBlurriness>0?e:t).get(g)),g}function M(E){let g=!1,C=x(E);C===null?p(o,l):C&&C.isColor&&(p(C,1),g=!0);let A=n.xr.getEnvironmentBlendMode();A==="additive"?i.buffers.color.setClear(0,0,0,1,a):A==="alpha-blend"&&i.buffers.color.setClear(0,0,0,0,a),(n.autoClear||g)&&(i.buffers.depth.setTest(!0),i.buffers.depth.setMask(!0),i.buffers.color.setMask(!0),n.clear(n.autoClearColor,n.autoClearDepth,n.autoClearStencil))}function m(E,g){let C=x(g);C&&(C.isCubeTexture||C.mapping===So)?(h===void 0&&(h=new $(new Ee(1,1,1),new qn({name:"BackgroundCubeMaterial",uniforms:Fs(li.backgroundCube.uniforms),vertexShader:li.backgroundCube.vertexShader,fragmentShader:li.backgroundCube.fragmentShader,side:je,depthTest:!1,depthWrite:!1,fog:!1})),h.geometry.deleteAttribute("normal"),h.geometry.deleteAttribute("uv"),h.onBeforeRender=function(A,_,T){this.matrixWorld.copyPosition(T.matrixWorld)},Object.defineProperty(h.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),s.update(h)),Os.copy(g.backgroundRotation),Os.x*=-1,Os.y*=-1,Os.z*=-1,C.isCubeTexture&&C.isRenderTargetTexture===!1&&(Os.y*=-1,Os.z*=-1),h.material.uniforms.envMap.value=C,h.material.uniforms.flipEnvMap.value=C.isCubeTexture&&C.isRenderTargetTexture===!1?-1:1,h.material.uniforms.backgroundBlurriness.value=g.backgroundBlurriness,h.material.uniforms.backgroundIntensity.value=g.backgroundIntensity,h.material.uniforms.backgroundRotation.value.setFromMatrix4(ax.makeRotationFromEuler(Os)),h.material.toneMapped=pe.getTransfer(C.colorSpace)!==Me,(d!==C||u!==C.version||f!==n.toneMapping)&&(h.material.needsUpdate=!0,d=C,u=C.version,f=n.toneMapping),h.layers.enableAll(),E.unshift(h,h.geometry,h.material,0,0,null)):C&&C.isTexture&&(c===void 0&&(c=new $(new we(2,2),new qn({name:"BackgroundMaterial",uniforms:Fs(li.background.uniforms),vertexShader:li.background.vertexShader,fragmentShader:li.background.fragmentShader,side:Si,depthTest:!1,depthWrite:!1,fog:!1})),c.geometry.deleteAttribute("normal"),Object.defineProperty(c.material,"map",{get:function(){return this.uniforms.t2D.value}}),s.update(c)),c.material.uniforms.t2D.value=C,c.material.uniforms.backgroundIntensity.value=g.backgroundIntensity,c.material.toneMapped=pe.getTransfer(C.colorSpace)!==Me,C.matrixAutoUpdate===!0&&C.updateMatrix(),c.material.uniforms.uvTransform.value.copy(C.matrix),(d!==C||u!==C.version||f!==n.toneMapping)&&(c.material.needsUpdate=!0,d=C,u=C.version,f=n.toneMapping),c.layers.enableAll(),E.unshift(c,c.geometry,c.material,0,0,null))}function p(E,g){E.getRGB(Xl,mh(n)),i.buffers.color.setClear(Xl.r,Xl.g,Xl.b,g,a)}function S(){h!==void 0&&(h.geometry.dispose(),h.material.dispose()),c!==void 0&&(c.geometry.dispose(),c.material.dispose())}return{getClearColor:function(){return o},setClearColor:function(E,g=1){o.set(E),l=g,p(o,l)},getClearAlpha:function(){return l},setClearAlpha:function(E){l=E,p(o,l)},render:M,addToRenderList:m,dispose:S}}function cx(n,t){let e=n.getParameter(n.MAX_VERTEX_ATTRIBS),i={},s=u(null),r=s,a=!1;function o(y,w,P,D,N){let H=!1,U=d(D,P,w);r!==U&&(r=U,c(r.object)),H=f(y,D,P,N),H&&x(y,D,P,N),N!==null&&t.update(N,n.ELEMENT_ARRAY_BUFFER),(H||a)&&(a=!1,g(y,w,P,D),N!==null&&n.bindBuffer(n.ELEMENT_ARRAY_BUFFER,t.get(N).buffer))}function l(){return n.createVertexArray()}function c(y){return n.bindVertexArray(y)}function h(y){return n.deleteVertexArray(y)}function d(y,w,P){let D=P.wireframe===!0,N=i[y.id];N===void 0&&(N={},i[y.id]=N);let H=N[w.id];H===void 0&&(H={},N[w.id]=H);let U=H[D];return U===void 0&&(U=u(l()),H[D]=U),U}function u(y){let w=[],P=[],D=[];for(let N=0;N<e;N++)w[N]=0,P[N]=0,D[N]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:w,enabledAttributes:P,attributeDivisors:D,object:y,attributes:{},index:null}}function f(y,w,P,D){let N=r.attributes,H=w.attributes,U=0,k=P.getAttributes();for(let F in k)if(k[F].location>=0){let q=N[F],et=H[F];if(et===void 0&&(F==="instanceMatrix"&&y.instanceMatrix&&(et=y.instanceMatrix),F==="instanceColor"&&y.instanceColor&&(et=y.instanceColor)),q===void 0||q.attribute!==et||et&&q.data!==et.data)return!0;U++}return r.attributesNum!==U||r.index!==D}function x(y,w,P,D){let N={},H=w.attributes,U=0,k=P.getAttributes();for(let F in k)if(k[F].location>=0){let q=H[F];q===void 0&&(F==="instanceMatrix"&&y.instanceMatrix&&(q=y.instanceMatrix),F==="instanceColor"&&y.instanceColor&&(q=y.instanceColor));let et={};et.attribute=q,q&&q.data&&(et.data=q.data),N[F]=et,U++}r.attributes=N,r.attributesNum=U,r.index=D}function M(){let y=r.newAttributes;for(let w=0,P=y.length;w<P;w++)y[w]=0}function m(y){p(y,0)}function p(y,w){let P=r.newAttributes,D=r.enabledAttributes,N=r.attributeDivisors;P[y]=1,D[y]===0&&(n.enableVertexAttribArray(y),D[y]=1),N[y]!==w&&(n.vertexAttribDivisor(y,w),N[y]=w)}function S(){let y=r.newAttributes,w=r.enabledAttributes;for(let P=0,D=w.length;P<D;P++)w[P]!==y[P]&&(n.disableVertexAttribArray(P),w[P]=0)}function E(y,w,P,D,N,H,U){U===!0?n.vertexAttribIPointer(y,w,P,N,H):n.vertexAttribPointer(y,w,P,D,N,H)}function g(y,w,P,D){M();let N=D.attributes,H=P.getAttributes(),U=w.defaultAttributeValues;for(let k in H){let F=H[k];if(F.location>=0){let G=N[k];if(G===void 0&&(k==="instanceMatrix"&&y.instanceMatrix&&(G=y.instanceMatrix),k==="instanceColor"&&y.instanceColor&&(G=y.instanceColor)),G!==void 0){let q=G.normalized,et=G.itemSize,nt=t.get(G);if(nt===void 0)continue;let rt=nt.buffer,B=nt.type,Z=nt.bytesPerElement,ct=B===n.INT||B===n.UNSIGNED_INT||G.gpuType===hl;if(G.isInterleavedBufferAttribute){let z=G.data,j=z.stride,ft=G.offset;if(z.isInstancedInterleavedBuffer){for(let dt=0;dt<F.locationSize;dt++)p(F.location+dt,z.meshPerAttribute);y.isInstancedMesh!==!0&&D._maxInstanceCount===void 0&&(D._maxInstanceCount=z.meshPerAttribute*z.count)}else for(let dt=0;dt<F.locationSize;dt++)m(F.location+dt);n.bindBuffer(n.ARRAY_BUFFER,rt);for(let dt=0;dt<F.locationSize;dt++)E(F.location+dt,et/F.locationSize,B,q,j*Z,(ft+et/F.locationSize*dt)*Z,ct)}else{if(G.isInstancedBufferAttribute){for(let z=0;z<F.locationSize;z++)p(F.location+z,G.meshPerAttribute);y.isInstancedMesh!==!0&&D._maxInstanceCount===void 0&&(D._maxInstanceCount=G.meshPerAttribute*G.count)}else for(let z=0;z<F.locationSize;z++)m(F.location+z);n.bindBuffer(n.ARRAY_BUFFER,rt);for(let z=0;z<F.locationSize;z++)E(F.location+z,et/F.locationSize,B,q,et*Z,et/F.locationSize*z*Z,ct)}}else if(U!==void 0){let q=U[k];if(q!==void 0)switch(q.length){case 2:n.vertexAttrib2fv(F.location,q);break;case 3:n.vertexAttrib3fv(F.location,q);break;case 4:n.vertexAttrib4fv(F.location,q);break;default:n.vertexAttrib1fv(F.location,q)}}}}S()}function C(){T();for(let y in i){let w=i[y];for(let P in w){let D=w[P];for(let N in D)h(D[N].object),delete D[N];delete w[P]}delete i[y]}}function A(y){if(i[y.id]===void 0)return;let w=i[y.id];for(let P in w){let D=w[P];for(let N in D)h(D[N].object),delete D[N];delete w[P]}delete i[y.id]}function _(y){for(let w in i){let P=i[w];if(P[y.id]===void 0)continue;let D=P[y.id];for(let N in D)h(D[N].object),delete D[N];delete P[y.id]}}function T(){v(),a=!0,r!==s&&(r=s,c(r.object))}function v(){s.geometry=null,s.program=null,s.wireframe=!1}return{setup:o,reset:T,resetDefaultState:v,dispose:C,releaseStatesOfGeometry:A,releaseStatesOfProgram:_,initAttributes:M,enableAttribute:m,disableUnusedAttributes:S}}function hx(n,t,e){let i;function s(c){i=c}function r(c,h){n.drawArrays(i,c,h),e.update(h,i,1)}function a(c,h,d){d!==0&&(n.drawArraysInstanced(i,c,h,d),e.update(h,i,d))}function o(c,h,d){if(d===0)return;t.get("WEBGL_multi_draw").multiDrawArraysWEBGL(i,c,0,h,0,d);let f=0;for(let x=0;x<d;x++)f+=h[x];e.update(f,i,1)}function l(c,h,d,u){if(d===0)return;let f=t.get("WEBGL_multi_draw");if(f===null)for(let x=0;x<c.length;x++)a(c[x],h[x],u[x]);else{f.multiDrawArraysInstancedWEBGL(i,c,0,h,0,u,0,d);let x=0;for(let M=0;M<d;M++)x+=h[M]*u[M];e.update(x,i,1)}}this.setMode=s,this.render=r,this.renderInstances=a,this.renderMultiDraw=o,this.renderMultiDrawInstances=l}function ux(n,t,e,i){let s;function r(){if(s!==void 0)return s;if(t.has("EXT_texture_filter_anisotropic")===!0){let _=t.get("EXT_texture_filter_anisotropic");s=n.getParameter(_.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else s=0;return s}function a(_){return!(_!==Un&&i.convert(_)!==n.getParameter(n.IMPLEMENTATION_COLOR_READ_FORMAT))}function o(_){let T=_===vr&&(t.has("EXT_color_buffer_half_float")||t.has("EXT_color_buffer_float"));return!(_!==ai&&i.convert(_)!==n.getParameter(n.IMPLEMENTATION_COLOR_READ_TYPE)&&_!==Yn&&!T)}function l(_){if(_==="highp"){if(n.getShaderPrecisionFormat(n.VERTEX_SHADER,n.HIGH_FLOAT).precision>0&&n.getShaderPrecisionFormat(n.FRAGMENT_SHADER,n.HIGH_FLOAT).precision>0)return"highp";_="mediump"}return _==="mediump"&&n.getShaderPrecisionFormat(n.VERTEX_SHADER,n.MEDIUM_FLOAT).precision>0&&n.getShaderPrecisionFormat(n.FRAGMENT_SHADER,n.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let c=e.precision!==void 0?e.precision:"highp",h=l(c);h!==c&&(console.warn("THREE.WebGLRenderer:",c,"not supported, using",h,"instead."),c=h);let d=e.logarithmicDepthBuffer===!0,u=e.reverseDepthBuffer===!0&&t.has("EXT_clip_control"),f=n.getParameter(n.MAX_TEXTURE_IMAGE_UNITS),x=n.getParameter(n.MAX_VERTEX_TEXTURE_IMAGE_UNITS),M=n.getParameter(n.MAX_TEXTURE_SIZE),m=n.getParameter(n.MAX_CUBE_MAP_TEXTURE_SIZE),p=n.getParameter(n.MAX_VERTEX_ATTRIBS),S=n.getParameter(n.MAX_VERTEX_UNIFORM_VECTORS),E=n.getParameter(n.MAX_VARYING_VECTORS),g=n.getParameter(n.MAX_FRAGMENT_UNIFORM_VECTORS),C=x>0,A=n.getParameter(n.MAX_SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:r,getMaxPrecision:l,textureFormatReadable:a,textureTypeReadable:o,precision:c,logarithmicDepthBuffer:d,reverseDepthBuffer:u,maxTextures:f,maxVertexTextures:x,maxTextureSize:M,maxCubemapSize:m,maxAttributes:p,maxVertexUniforms:S,maxVaryings:E,maxFragmentUniforms:g,vertexTextures:C,maxSamples:A}}function dx(n){let t=this,e=null,i=0,s=!1,r=!1,a=new ti,o=new Qt,l={value:null,needsUpdate:!1};this.uniform=l,this.numPlanes=0,this.numIntersection=0,this.init=function(d,u){let f=d.length!==0||u||i!==0||s;return s=u,i=d.length,f},this.beginShadows=function(){r=!0,h(null)},this.endShadows=function(){r=!1},this.setGlobalState=function(d,u){e=h(d,u,0)},this.setState=function(d,u,f){let x=d.clippingPlanes,M=d.clipIntersection,m=d.clipShadows,p=n.get(d);if(!s||x===null||x.length===0||r&&!m)r?h(null):c();else{let S=r?0:i,E=S*4,g=p.clippingState||null;l.value=g,g=h(x,u,E,f);for(let C=0;C!==E;++C)g[C]=e[C];p.clippingState=g,this.numIntersection=M?this.numPlanes:0,this.numPlanes+=S}};function c(){l.value!==e&&(l.value=e,l.needsUpdate=i>0),t.numPlanes=i,t.numIntersection=0}function h(d,u,f,x){let M=d!==null?d.length:0,m=null;if(M!==0){if(m=l.value,x!==!0||m===null){let p=f+M*4,S=u.matrixWorldInverse;o.getNormalMatrix(S),(m===null||m.length<p)&&(m=new Float32Array(p));for(let E=0,g=f;E!==M;++E,g+=4)a.copy(d[E]).applyMatrix4(S,o),a.normal.toArray(m,g),m[g+3]=a.constant}l.value=m,l.needsUpdate=!0}return t.numPlanes=M,t.numIntersection=0,m}}function fx(n){let t=new WeakMap;function e(a,o){return o===al?a.mapping=Ls:o===ll&&(a.mapping=Ds),a}function i(a){if(a&&a.isTexture){let o=a.mapping;if(o===al||o===ll)if(t.has(a)){let l=t.get(a).texture;return e(l,a.mapping)}else{let l=a.image;if(l&&l.height>0){let c=new La(l.height);return c.fromEquirectangularTexture(n,a),t.set(a,c),a.addEventListener("dispose",s),e(c.texture,a.mapping)}else return null}}return a}function s(a){let o=a.target;o.removeEventListener("dispose",s);let l=t.get(o);l!==void 0&&(t.delete(o),l.dispose())}function r(){t=new WeakMap}return{get:i,dispose:r}}var Sr=4,Xd=[.125,.215,.35,.446,.526,.582],ks=20,vh=new vo,qd=new Ot,Mh=null,Eh=0,Sh=0,wh=!1,Bs=(1+Math.sqrt(5))/2,Er=1/Bs,Yd=[new O(-Bs,Er,0),new O(Bs,Er,0),new O(-Er,0,Bs),new O(Er,0,Bs),new O(0,Bs,-Er),new O(0,Bs,Er),new O(-1,1,-1),new O(1,1,-1),new O(-1,1,1),new O(1,1,1)],Tr=class{constructor(t){this._renderer=t,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._lodPlanes=[],this._sizeLods=[],this._sigmas=[],this._blurMaterial=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._compileMaterial(this._blurMaterial)}fromScene(t,e=0,i=.1,s=100){Mh=this._renderer.getRenderTarget(),Eh=this._renderer.getActiveCubeFace(),Sh=this._renderer.getActiveMipmapLevel(),wh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(256);let r=this._allocateTargets();return r.depthBuffer=!0,this._sceneToCubeUV(t,i,s,r),e>0&&this._blur(r,0,0,e),this._applyPMREM(r),this._cleanup(r),r}fromEquirectangular(t,e=null){return this._fromTexture(t,e)}fromCubemap(t,e=null){return this._fromTexture(t,e)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=Jd(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=Zd(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose()}_setSize(t){this._lodMax=Math.floor(Math.log2(t)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let t=0;t<this._lodPlanes.length;t++)this._lodPlanes[t].dispose()}_cleanup(t){this._renderer.setRenderTarget(Mh,Eh,Sh),this._renderer.xr.enabled=wh,t.scissorTest=!1,ql(t,0,0,t.width,t.height)}_fromTexture(t,e){t.mapping===Ls||t.mapping===Ds?this._setSize(t.image.length===0?16:t.image[0].width||t.image[0].image.width):this._setSize(t.image.width/4),Mh=this._renderer.getRenderTarget(),Eh=this._renderer.getActiveCubeFace(),Sh=this._renderer.getActiveMipmapLevel(),wh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;let i=e||this._allocateTargets();return this._textureToCubeUV(t,i),this._applyPMREM(i),this._cleanup(i),i}_allocateTargets(){let t=3*Math.max(this._cubeSize,112),e=4*this._cubeSize,i={magFilter:Xn,minFilter:Xn,generateMipmaps:!1,type:vr,format:Un,colorSpace:As,depthBuffer:!1},s=$d(t,e,i);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==t||this._pingPongRenderTarget.height!==e){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=$d(t,e,i);let{_lodMax:r}=this;({sizeLods:this._sizeLods,lodPlanes:this._lodPlanes,sigmas:this._sigmas}=px(r)),this._blurMaterial=mx(r,t,e)}return s}_compileMaterial(t){let e=new $(this._lodPlanes[0],t);this._renderer.compile(e,vh)}_sceneToCubeUV(t,e,i,s){let o=new on(90,1,e,i),l=[1,-1,1,1,1,1],c=[1,1,1,-1,-1,-1],h=this._renderer,d=h.autoClear,u=h.toneMapping;h.getClearColor(qd),h.toneMapping=Ci,h.autoClear=!1;let f=new Se({name:"PMREM.Background",side:je,depthWrite:!1,depthTest:!1}),x=new $(new Ee,f),M=!1,m=t.background;m?m.isColor&&(f.color.copy(m),t.background=null,M=!0):(f.color.copy(qd),M=!0);for(let p=0;p<6;p++){let S=p%3;S===0?(o.up.set(0,l[p],0),o.lookAt(c[p],0,0)):S===1?(o.up.set(0,0,l[p]),o.lookAt(0,c[p],0)):(o.up.set(0,l[p],0),o.lookAt(0,0,c[p]));let E=this._cubeSize;ql(s,S*E,p>2?E:0,E,E),h.setRenderTarget(s),M&&h.render(x,o),h.render(t,o)}x.geometry.dispose(),x.material.dispose(),h.toneMapping=u,h.autoClear=d,t.background=m}_textureToCubeUV(t,e){let i=this._renderer,s=t.mapping===Ls||t.mapping===Ds;s?(this._cubemapMaterial===null&&(this._cubemapMaterial=Jd()),this._cubemapMaterial.uniforms.flipEnvMap.value=t.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=Zd());let r=s?this._cubemapMaterial:this._equirectMaterial,a=new $(this._lodPlanes[0],r),o=r.uniforms;o.envMap.value=t;let l=this._cubeSize;ql(e,0,0,3*l,2*l),i.setRenderTarget(e),i.render(a,vh)}_applyPMREM(t){let e=this._renderer,i=e.autoClear;e.autoClear=!1;let s=this._lodPlanes.length;for(let r=1;r<s;r++){let a=Math.sqrt(this._sigmas[r]*this._sigmas[r]-this._sigmas[r-1]*this._sigmas[r-1]),o=Yd[(s-r-1)%Yd.length];this._blur(t,r-1,r,a,o)}e.autoClear=i}_blur(t,e,i,s,r){let a=this._pingPongRenderTarget;this._halfBlur(t,a,e,i,s,"latitudinal",r),this._halfBlur(a,t,i,i,s,"longitudinal",r)}_halfBlur(t,e,i,s,r,a,o){let l=this._renderer,c=this._blurMaterial;a!=="latitudinal"&&a!=="longitudinal"&&console.error("blur direction must be either latitudinal or longitudinal!");let h=3,d=new $(this._lodPlanes[s],c),u=c.uniforms,f=this._sizeLods[i]-1,x=isFinite(r)?Math.PI/(2*f):2*Math.PI/(2*ks-1),M=r/x,m=isFinite(r)?1+Math.floor(h*M):ks;m>ks&&console.warn(`sigmaRadians, ${r}, is too large and will clip, as it requested ${m} samples when the maximum is set to ${ks}`);let p=[],S=0;for(let _=0;_<ks;++_){let T=_/M,v=Math.exp(-T*T/2);p.push(v),_===0?S+=v:_<m&&(S+=2*v)}for(let _=0;_<p.length;_++)p[_]=p[_]/S;u.envMap.value=t.texture,u.samples.value=m,u.weights.value=p,u.latitudinal.value=a==="latitudinal",o&&(u.poleAxis.value=o);let{_lodMax:E}=this;u.dTheta.value=x,u.mipInt.value=E-i;let g=this._sizeLods[s],C=3*g*(s>E-Sr?s-E+Sr:0),A=4*(this._cubeSize-g);ql(e,C,A,3*g,2*g),l.setRenderTarget(e),l.render(d,vh)}};function px(n){let t=[],e=[],i=[],s=n,r=n-Sr+1+Xd.length;for(let a=0;a<r;a++){let o=Math.pow(2,s);e.push(o);let l=1/o;a>n-Sr?l=Xd[a-n+Sr-1]:a===0&&(l=0),i.push(l);let c=1/(o-2),h=-c,d=1+c,u=[h,h,d,h,d,d,h,h,d,d,h,d],f=6,x=6,M=3,m=2,p=1,S=new Float32Array(M*x*f),E=new Float32Array(m*x*f),g=new Float32Array(p*x*f);for(let A=0;A<f;A++){let _=A%3*2/3-1,T=A>2?0:-1,v=[_,T,0,_+2/3,T,0,_+2/3,T+1,0,_,T,0,_+2/3,T+1,0,_,T+1,0];S.set(v,M*x*A),E.set(u,m*x*A);let y=[A,A,A,A,A,A];g.set(y,p*x*A)}let C=new qe;C.setAttribute("position",new gn(S,M)),C.setAttribute("uv",new gn(E,m)),C.setAttribute("faceIndex",new gn(g,p)),t.push(C),s>Sr&&s--}return{lodPlanes:t,sizeLods:e,sigmas:i}}function $d(n,t,e){let i=new ni(n,t,e);return i.texture.mapping=So,i.texture.name="PMREM.cubeUv",i.scissorTest=!0,i}function ql(n,t,e,i,s){n.viewport.set(t,e,i,s),n.scissor.set(t,e,i,s)}function mx(n,t,e){let i=new Float32Array(ks),s=new O(0,1,0);return new qn({name:"SphericalGaussianBlur",defines:{n:ks,CUBEUV_TEXEL_WIDTH:1/t,CUBEUV_TEXEL_HEIGHT:1/e,CUBEUV_MAX_MIP:`${n}.0`},uniforms:{envMap:{value:null},samples:{value:1},weights:{value:i},latitudinal:{value:!1},dTheta:{value:0},mipInt:{value:0},poleAxis:{value:s}},vertexShader:Uh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;
			uniform int samples;
			uniform float weights[ n ];
			uniform bool latitudinal;
			uniform float dTheta;
			uniform float mipInt;
			uniform vec3 poleAxis;

			#define ENVMAP_TYPE_CUBE_UV
			#include <cube_uv_reflection_fragment>

			vec3 getSample( float theta, vec3 axis ) {

				float cosTheta = cos( theta );
				// Rodrigues' axis-angle rotation
				vec3 sampleDirection = vOutputDirection * cosTheta
					+ cross( axis, vOutputDirection ) * sin( theta )
					+ axis * dot( axis, vOutputDirection ) * ( 1.0 - cosTheta );

				return bilinearCubeUV( envMap, sampleDirection, mipInt );

			}

			void main() {

				vec3 axis = latitudinal ? poleAxis : cross( poleAxis, vOutputDirection );

				if ( all( equal( axis, vec3( 0.0 ) ) ) ) {

					axis = vec3( vOutputDirection.z, 0.0, - vOutputDirection.x );

				}

				axis = normalize( axis );

				gl_FragColor = vec4( 0.0, 0.0, 0.0, 1.0 );
				gl_FragColor.rgb += weights[ 0 ] * getSample( 0.0, axis );

				for ( int i = 1; i < n; i++ ) {

					if ( i >= samples ) {

						break;

					}

					float theta = dTheta * float( i );
					gl_FragColor.rgb += weights[ i ] * getSample( -1.0 * theta, axis );
					gl_FragColor.rgb += weights[ i ] * getSample( theta, axis );

				}

			}
		`,blending:Ri,depthTest:!1,depthWrite:!1})}function Zd(){return new qn({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:Uh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;

			#include <common>

			void main() {

				vec3 outputDirection = normalize( vOutputDirection );
				vec2 uv = equirectUv( outputDirection );

				gl_FragColor = vec4( texture2D ( envMap, uv ).rgb, 1.0 );

			}
		`,blending:Ri,depthTest:!1,depthWrite:!1})}function Jd(){return new qn({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:Uh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:Ri,depthTest:!1,depthWrite:!1})}function Uh(){return`

		precision mediump float;
		precision mediump int;

		attribute float faceIndex;

		varying vec3 vOutputDirection;

		// RH coordinate system; PMREM face-indexing convention
		vec3 getDirection( vec2 uv, float face ) {

			uv = 2.0 * uv - 1.0;

			vec3 direction = vec3( uv, 1.0 );

			if ( face == 0.0 ) {

				direction = direction.zyx; // ( 1, v, u ) pos x

			} else if ( face == 1.0 ) {

				direction = direction.xzy;
				direction.xz *= -1.0; // ( -u, 1, -v ) pos y

			} else if ( face == 2.0 ) {

				direction.x *= -1.0; // ( -u, v, 1 ) pos z

			} else if ( face == 3.0 ) {

				direction = direction.zyx;
				direction.xz *= -1.0; // ( -1, v, -u ) neg x

			} else if ( face == 4.0 ) {

				direction = direction.xzy;
				direction.xy *= -1.0; // ( -u, -1, v ) neg y

			} else if ( face == 5.0 ) {

				direction.z *= -1.0; // ( u, v, -1 ) neg z

			}

			return direction;

		}

		void main() {

			vOutputDirection = getDirection( uv, faceIndex );
			gl_Position = vec4( position, 1.0 );

		}
	`}function gx(n){let t=new WeakMap,e=null;function i(o){if(o&&o.isTexture){let l=o.mapping,c=l===al||l===ll,h=l===Ls||l===Ds;if(c||h){let d=t.get(o),u=d!==void 0?d.texture.pmremVersion:0;if(o.isRenderTargetTexture&&o.pmremVersion!==u)return e===null&&(e=new Tr(n)),d=c?e.fromEquirectangular(o,d):e.fromCubemap(o,d),d.texture.pmremVersion=o.pmremVersion,t.set(o,d),d.texture;if(d!==void 0)return d.texture;{let f=o.image;return c&&f&&f.height>0||h&&f&&s(f)?(e===null&&(e=new Tr(n)),d=c?e.fromEquirectangular(o):e.fromCubemap(o),d.texture.pmremVersion=o.pmremVersion,t.set(o,d),o.addEventListener("dispose",r),d.texture):null}}}return o}function s(o){let l=0,c=6;for(let h=0;h<c;h++)o[h]!==void 0&&l++;return l===c}function r(o){let l=o.target;l.removeEventListener("dispose",r);let c=t.get(l);c!==void 0&&(t.delete(l),c.dispose())}function a(){t=new WeakMap,e!==null&&(e.dispose(),e=null)}return{get:i,dispose:a}}function xx(n){let t={};function e(i){if(t[i]!==void 0)return t[i];let s;switch(i){case"WEBGL_depth_texture":s=n.getExtension("WEBGL_depth_texture")||n.getExtension("MOZ_WEBGL_depth_texture")||n.getExtension("WEBKIT_WEBGL_depth_texture");break;case"EXT_texture_filter_anisotropic":s=n.getExtension("EXT_texture_filter_anisotropic")||n.getExtension("MOZ_EXT_texture_filter_anisotropic")||n.getExtension("WEBKIT_EXT_texture_filter_anisotropic");break;case"WEBGL_compressed_texture_s3tc":s=n.getExtension("WEBGL_compressed_texture_s3tc")||n.getExtension("MOZ_WEBGL_compressed_texture_s3tc")||n.getExtension("WEBKIT_WEBGL_compressed_texture_s3tc");break;case"WEBGL_compressed_texture_pvrtc":s=n.getExtension("WEBGL_compressed_texture_pvrtc")||n.getExtension("WEBKIT_WEBGL_compressed_texture_pvrtc");break;default:s=n.getExtension(i)}return t[i]=s,s}return{has:function(i){return e(i)!==null},init:function(){e("EXT_color_buffer_float"),e("WEBGL_clip_cull_distance"),e("OES_texture_float_linear"),e("EXT_color_buffer_half_float"),e("WEBGL_multisampled_render_to_texture"),e("WEBGL_render_shared_exponent")},get:function(i){let s=e(i);return s===null&&Ns("THREE.WebGLRenderer: "+i+" extension not supported."),s}}}function yx(n,t,e,i){let s={},r=new WeakMap;function a(d){let u=d.target;u.index!==null&&t.remove(u.index);for(let x in u.attributes)t.remove(u.attributes[x]);u.removeEventListener("dispose",a),delete s[u.id];let f=r.get(u);f&&(t.remove(f),r.delete(u)),i.releaseStatesOfGeometry(u),u.isInstancedBufferGeometry===!0&&delete u._maxInstanceCount,e.memory.geometries--}function o(d,u){return s[u.id]===!0||(u.addEventListener("dispose",a),s[u.id]=!0,e.memory.geometries++),u}function l(d){let u=d.attributes;for(let f in u)t.update(u[f],n.ARRAY_BUFFER)}function c(d){let u=[],f=d.index,x=d.attributes.position,M=0;if(f!==null){let S=f.array;M=f.version;for(let E=0,g=S.length;E<g;E+=3){let C=S[E+0],A=S[E+1],_=S[E+2];u.push(C,A,A,_,_,C)}}else if(x!==void 0){let S=x.array;M=x.version;for(let E=0,g=S.length/3-1;E<g;E+=3){let C=E+0,A=E+1,_=E+2;u.push(C,A,A,_,_,C)}}else return;let m=new(ph(u)?jr:Qr)(u,1);m.version=M;let p=r.get(d);p&&t.remove(p),r.set(d,m)}function h(d){let u=r.get(d);if(u){let f=d.index;f!==null&&u.version<f.version&&c(d)}else c(d);return r.get(d)}return{get:o,update:l,getWireframeAttribute:h}}function _x(n,t,e){let i;function s(u){i=u}let r,a;function o(u){r=u.type,a=u.bytesPerElement}function l(u,f){n.drawElements(i,f,r,u*a),e.update(f,i,1)}function c(u,f,x){x!==0&&(n.drawElementsInstanced(i,f,r,u*a,x),e.update(f,i,x))}function h(u,f,x){if(x===0)return;t.get("WEBGL_multi_draw").multiDrawElementsWEBGL(i,f,0,r,u,0,x);let m=0;for(let p=0;p<x;p++)m+=f[p];e.update(m,i,1)}function d(u,f,x,M){if(x===0)return;let m=t.get("WEBGL_multi_draw");if(m===null)for(let p=0;p<u.length;p++)c(u[p]/a,f[p],M[p]);else{m.multiDrawElementsInstancedWEBGL(i,f,0,r,u,0,M,0,x);let p=0;for(let S=0;S<x;S++)p+=f[S]*M[S];e.update(p,i,1)}}this.setMode=s,this.setIndex=o,this.render=l,this.renderInstances=c,this.renderMultiDraw=h,this.renderMultiDrawInstances=d}function vx(n){let t={geometries:0,textures:0},e={frame:0,calls:0,triangles:0,points:0,lines:0};function i(r,a,o){switch(e.calls++,a){case n.TRIANGLES:e.triangles+=o*(r/3);break;case n.LINES:e.lines+=o*(r/2);break;case n.LINE_STRIP:e.lines+=o*(r-1);break;case n.LINE_LOOP:e.lines+=o*r;break;case n.POINTS:e.points+=o*r;break;default:console.error("THREE.WebGLInfo: Unknown draw mode:",a);break}}function s(){e.calls=0,e.triangles=0,e.points=0,e.lines=0}return{memory:t,render:e,programs:null,autoReset:!0,reset:s,update:i}}function Mx(n,t,e){let i=new WeakMap,s=new Le;function r(a,o,l){let c=a.morphTargetInfluences,h=o.morphAttributes.position||o.morphAttributes.normal||o.morphAttributes.color,d=h!==void 0?h.length:0,u=i.get(o);if(u===void 0||u.count!==d){let v=function(){_.dispose(),i.delete(o),o.removeEventListener("dispose",v)};u!==void 0&&u.texture.dispose();let f=o.morphAttributes.position!==void 0,x=o.morphAttributes.normal!==void 0,M=o.morphAttributes.color!==void 0,m=o.morphAttributes.position||[],p=o.morphAttributes.normal||[],S=o.morphAttributes.color||[],E=0;f===!0&&(E=1),x===!0&&(E=2),M===!0&&(E=3);let g=o.attributes.position.count*E,C=1;g>t.maxTextureSize&&(C=Math.ceil(g/t.maxTextureSize),g=t.maxTextureSize);let A=new Float32Array(g*C*4*d),_=new Jr(A,g,C,d);_.type=Yn,_.needsUpdate=!0;let T=E*4;for(let y=0;y<d;y++){let w=m[y],P=p[y],D=S[y],N=g*C*4*y;for(let H=0;H<w.count;H++){let U=H*T;f===!0&&(s.fromBufferAttribute(w,H),A[N+U+0]=s.x,A[N+U+1]=s.y,A[N+U+2]=s.z,A[N+U+3]=0),x===!0&&(s.fromBufferAttribute(P,H),A[N+U+4]=s.x,A[N+U+5]=s.y,A[N+U+6]=s.z,A[N+U+7]=0),M===!0&&(s.fromBufferAttribute(D,H),A[N+U+8]=s.x,A[N+U+9]=s.y,A[N+U+10]=s.z,A[N+U+11]=D.itemSize===4?s.w:1)}}u={count:d,texture:_,size:new at(g,C)},i.set(o,u),o.addEventListener("dispose",v)}if(a.isInstancedMesh===!0&&a.morphTexture!==null)l.getUniforms().setValue(n,"morphTexture",a.morphTexture,e);else{let f=0;for(let M=0;M<c.length;M++)f+=c[M];let x=o.morphTargetsRelative?1:1-f;l.getUniforms().setValue(n,"morphTargetBaseInfluence",x),l.getUniforms().setValue(n,"morphTargetInfluences",c)}l.getUniforms().setValue(n,"morphTargetsTexture",u.texture,e),l.getUniforms().setValue(n,"morphTargetsTextureSize",u.size)}return{update:r}}function Ex(n,t,e,i){let s=new WeakMap;function r(l){let c=i.render.frame,h=l.geometry,d=t.get(l,h);if(s.get(d)!==c&&(t.update(d),s.set(d,c)),l.isInstancedMesh&&(l.hasEventListener("dispose",o)===!1&&l.addEventListener("dispose",o),s.get(l)!==c&&(e.update(l.instanceMatrix,n.ARRAY_BUFFER),l.instanceColor!==null&&e.update(l.instanceColor,n.ARRAY_BUFFER),s.set(l,c))),l.isSkinnedMesh){let u=l.skeleton;s.get(u)!==c&&(u.update(),s.set(u,c))}return d}function a(){s=new WeakMap}function o(l){let c=l.target;c.removeEventListener("dispose",o),e.remove(c.instanceMatrix),c.instanceColor!==null&&e.remove(c.instanceColor)}return{update:r,dispose:a}}var gf=new an,Kd=new so(1,1),xf=new Jr,yf=new Ca,_f=new eo,Qd=[],jd=[],tf=new Float32Array(16),ef=new Float32Array(9),nf=new Float32Array(4);function br(n,t,e){let i=n[0];if(i<=0||i>0)return n;let s=t*e,r=Qd[s];if(r===void 0&&(r=new Float32Array(s),Qd[s]=r),t!==0){i.toArray(r,0);for(let a=1,o=0;a!==t;++a)o+=e,n[a].toArray(r,o)}return r}function Ve(n,t){if(n.length!==t.length)return!1;for(let e=0,i=n.length;e<i;e++)if(n[e]!==t[e])return!1;return!0}function We(n,t){for(let e=0,i=t.length;e<i;e++)n[e]=t[e]}function Zl(n,t){let e=jd[t];e===void 0&&(e=new Int32Array(t),jd[t]=e);for(let i=0;i!==t;++i)e[i]=n.allocateTextureUnit();return e}function Sx(n,t){let e=this.cache;e[0]!==t&&(n.uniform1f(this.addr,t),e[0]=t)}function wx(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(n.uniform2f(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(Ve(e,t))return;n.uniform2fv(this.addr,t),We(e,t)}}function Tx(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(n.uniform3f(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else if(t.r!==void 0)(e[0]!==t.r||e[1]!==t.g||e[2]!==t.b)&&(n.uniform3f(this.addr,t.r,t.g,t.b),e[0]=t.r,e[1]=t.g,e[2]=t.b);else{if(Ve(e,t))return;n.uniform3fv(this.addr,t),We(e,t)}}function bx(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(n.uniform4f(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(Ve(e,t))return;n.uniform4fv(this.addr,t),We(e,t)}}function Ax(n,t){let e=this.cache,i=t.elements;if(i===void 0){if(Ve(e,t))return;n.uniformMatrix2fv(this.addr,!1,t),We(e,t)}else{if(Ve(e,i))return;nf.set(i),n.uniformMatrix2fv(this.addr,!1,nf),We(e,i)}}function Rx(n,t){let e=this.cache,i=t.elements;if(i===void 0){if(Ve(e,t))return;n.uniformMatrix3fv(this.addr,!1,t),We(e,t)}else{if(Ve(e,i))return;ef.set(i),n.uniformMatrix3fv(this.addr,!1,ef),We(e,i)}}function Cx(n,t){let e=this.cache,i=t.elements;if(i===void 0){if(Ve(e,t))return;n.uniformMatrix4fv(this.addr,!1,t),We(e,t)}else{if(Ve(e,i))return;tf.set(i),n.uniformMatrix4fv(this.addr,!1,tf),We(e,i)}}function Px(n,t){let e=this.cache;e[0]!==t&&(n.uniform1i(this.addr,t),e[0]=t)}function Ix(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(n.uniform2i(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(Ve(e,t))return;n.uniform2iv(this.addr,t),We(e,t)}}function Lx(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(n.uniform3i(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else{if(Ve(e,t))return;n.uniform3iv(this.addr,t),We(e,t)}}function Dx(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(n.uniform4i(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(Ve(e,t))return;n.uniform4iv(this.addr,t),We(e,t)}}function Ux(n,t){let e=this.cache;e[0]!==t&&(n.uniform1ui(this.addr,t),e[0]=t)}function Nx(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(n.uniform2ui(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(Ve(e,t))return;n.uniform2uiv(this.addr,t),We(e,t)}}function Fx(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(n.uniform3ui(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else{if(Ve(e,t))return;n.uniform3uiv(this.addr,t),We(e,t)}}function Ox(n,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(n.uniform4ui(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(Ve(e,t))return;n.uniform4uiv(this.addr,t),We(e,t)}}function Hx(n,t,e){let i=this.cache,s=e.allocateTextureUnit();i[0]!==s&&(n.uniform1i(this.addr,s),i[0]=s);let r;this.type===n.SAMPLER_2D_SHADOW?(Kd.compareFunction=dh,r=Kd):r=gf,e.setTexture2D(t||r,s)}function Bx(n,t,e){let i=this.cache,s=e.allocateTextureUnit();i[0]!==s&&(n.uniform1i(this.addr,s),i[0]=s),e.setTexture3D(t||yf,s)}function kx(n,t,e){let i=this.cache,s=e.allocateTextureUnit();i[0]!==s&&(n.uniform1i(this.addr,s),i[0]=s),e.setTextureCube(t||_f,s)}function zx(n,t,e){let i=this.cache,s=e.allocateTextureUnit();i[0]!==s&&(n.uniform1i(this.addr,s),i[0]=s),e.setTexture2DArray(t||xf,s)}function Gx(n){switch(n){case 5126:return Sx;case 35664:return wx;case 35665:return Tx;case 35666:return bx;case 35674:return Ax;case 35675:return Rx;case 35676:return Cx;case 5124:case 35670:return Px;case 35667:case 35671:return Ix;case 35668:case 35672:return Lx;case 35669:case 35673:return Dx;case 5125:return Ux;case 36294:return Nx;case 36295:return Fx;case 36296:return Ox;case 35678:case 36198:case 36298:case 36306:case 35682:return Hx;case 35679:case 36299:case 36307:return Bx;case 35680:case 36300:case 36308:case 36293:return kx;case 36289:case 36303:case 36311:case 36292:return zx}}function Vx(n,t){n.uniform1fv(this.addr,t)}function Wx(n,t){let e=br(t,this.size,2);n.uniform2fv(this.addr,e)}function Xx(n,t){let e=br(t,this.size,3);n.uniform3fv(this.addr,e)}function qx(n,t){let e=br(t,this.size,4);n.uniform4fv(this.addr,e)}function Yx(n,t){let e=br(t,this.size,4);n.uniformMatrix2fv(this.addr,!1,e)}function $x(n,t){let e=br(t,this.size,9);n.uniformMatrix3fv(this.addr,!1,e)}function Zx(n,t){let e=br(t,this.size,16);n.uniformMatrix4fv(this.addr,!1,e)}function Jx(n,t){n.uniform1iv(this.addr,t)}function Kx(n,t){n.uniform2iv(this.addr,t)}function Qx(n,t){n.uniform3iv(this.addr,t)}function jx(n,t){n.uniform4iv(this.addr,t)}function ty(n,t){n.uniform1uiv(this.addr,t)}function ey(n,t){n.uniform2uiv(this.addr,t)}function ny(n,t){n.uniform3uiv(this.addr,t)}function iy(n,t){n.uniform4uiv(this.addr,t)}function sy(n,t,e){let i=this.cache,s=t.length,r=Zl(e,s);Ve(i,r)||(n.uniform1iv(this.addr,r),We(i,r));for(let a=0;a!==s;++a)e.setTexture2D(t[a]||gf,r[a])}function ry(n,t,e){let i=this.cache,s=t.length,r=Zl(e,s);Ve(i,r)||(n.uniform1iv(this.addr,r),We(i,r));for(let a=0;a!==s;++a)e.setTexture3D(t[a]||yf,r[a])}function oy(n,t,e){let i=this.cache,s=t.length,r=Zl(e,s);Ve(i,r)||(n.uniform1iv(this.addr,r),We(i,r));for(let a=0;a!==s;++a)e.setTextureCube(t[a]||_f,r[a])}function ay(n,t,e){let i=this.cache,s=t.length,r=Zl(e,s);Ve(i,r)||(n.uniform1iv(this.addr,r),We(i,r));for(let a=0;a!==s;++a)e.setTexture2DArray(t[a]||xf,r[a])}function ly(n){switch(n){case 5126:return Vx;case 35664:return Wx;case 35665:return Xx;case 35666:return qx;case 35674:return Yx;case 35675:return $x;case 35676:return Zx;case 5124:case 35670:return Jx;case 35667:case 35671:return Kx;case 35668:case 35672:return Qx;case 35669:case 35673:return jx;case 5125:return ty;case 36294:return ey;case 36295:return ny;case 36296:return iy;case 35678:case 36198:case 36298:case 36306:case 35682:return sy;case 35679:case 36299:case 36307:return ry;case 35680:case 36300:case 36308:case 36293:return oy;case 36289:case 36303:case 36311:case 36292:return ay}}var bh=class{constructor(t,e,i){this.id=t,this.addr=i,this.cache=[],this.type=e.type,this.setValue=Gx(e.type)}},Ah=class{constructor(t,e,i){this.id=t,this.addr=i,this.cache=[],this.type=e.type,this.size=e.size,this.setValue=ly(e.type)}},Rh=class{constructor(t){this.id=t,this.seq=[],this.map={}}setValue(t,e,i){let s=this.seq;for(let r=0,a=s.length;r!==a;++r){let o=s[r];o.setValue(t,e[o.id],i)}}},Th=/(\w+)(\])?(\[|\.)?/g;function sf(n,t){n.seq.push(t),n.map[t.id]=t}function cy(n,t,e){let i=n.name,s=i.length;for(Th.lastIndex=0;;){let r=Th.exec(i),a=Th.lastIndex,o=r[1],l=r[2]==="]",c=r[3];if(l&&(o=o|0),c===void 0||c==="["&&a+2===s){sf(e,c===void 0?new bh(o,n,t):new Ah(o,n,t));break}else{let d=e.map[o];d===void 0&&(d=new Rh(o),sf(e,d)),e=d}}}var wr=class{constructor(t,e){this.seq=[],this.map={};let i=t.getProgramParameter(e,t.ACTIVE_UNIFORMS);for(let s=0;s<i;++s){let r=t.getActiveUniform(e,s),a=t.getUniformLocation(e,r.name);cy(r,a,this)}}setValue(t,e,i,s){let r=this.map[e];r!==void 0&&r.setValue(t,i,s)}setOptional(t,e,i){let s=e[i];s!==void 0&&this.setValue(t,i,s)}static upload(t,e,i,s){for(let r=0,a=e.length;r!==a;++r){let o=e[r],l=i[o.id];l.needsUpdate!==!1&&o.setValue(t,l.value,s)}}static seqWithValue(t,e){let i=[];for(let s=0,r=t.length;s!==r;++s){let a=t[s];a.id in e&&i.push(a)}return i}};function rf(n,t,e){let i=n.createShader(t);return n.shaderSource(i,e),n.compileShader(i),i}var hy=37297,uy=0;function dy(n,t){let e=n.split(`
`),i=[],s=Math.max(t-6,0),r=Math.min(t+6,e.length);for(let a=s;a<r;a++){let o=a+1;i.push(`${o===t?">":" "} ${o}: ${e[a]}`)}return i.join(`
`)}var of=new Qt;function fy(n){pe._getMatrix(of,pe.workingColorSpace,n);let t=`mat3( ${of.elements.map(e=>e.toFixed(4))} )`;switch(pe.getTransfer(n)){case Yr:return[t,"LinearTransferOETF"];case Me:return[t,"sRGBTransferOETF"];default:return console.warn("THREE.WebGLProgram: Unsupported color space: ",n),[t,"LinearTransferOETF"]}}function af(n,t,e){let i=n.getShaderParameter(t,n.COMPILE_STATUS),s=n.getShaderInfoLog(t).trim();if(i&&s==="")return"";let r=/ERROR: 0:(\d+)/.exec(s);if(r){let a=parseInt(r[1]);return e.toUpperCase()+`

`+s+`

`+dy(n.getShaderSource(t),a)}else return s}function py(n,t){let e=fy(t);return[`vec4 ${n}( vec4 value ) {`,`	return ${e[1]}( vec4( value.rgb * ${e[0]}, value.a ) );`,"}"].join(`
`)}function my(n,t){let e;switch(t){case yd:e="Linear";break;case _d:e="Reinhard";break;case vd:e="Cineon";break;case ol:e="ACESFilmic";break;case Ed:e="AgX";break;case Sd:e="Neutral";break;case Md:e="Custom";break;default:console.warn("THREE.WebGLProgram: Unsupported toneMapping:",t),e="Linear"}return"vec3 "+n+"( vec3 color ) { return "+e+"ToneMapping( color ); }"}var Yl=new O;function gy(){pe.getLuminanceCoefficients(Yl);let n=Yl.x.toFixed(4),t=Yl.y.toFixed(4),e=Yl.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${n}, ${t}, ${e} );`,"	return dot( weights, rgb );","}"].join(`
`)}function xy(n){return[n.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",n.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter(Po).join(`
`)}function yy(n){let t=[];for(let e in n){let i=n[e];i!==!1&&t.push("#define "+e+" "+i)}return t.join(`
`)}function _y(n,t){let e={},i=n.getProgramParameter(t,n.ACTIVE_ATTRIBUTES);for(let s=0;s<i;s++){let r=n.getActiveAttrib(t,s),a=r.name,o=1;r.type===n.FLOAT_MAT2&&(o=2),r.type===n.FLOAT_MAT3&&(o=3),r.type===n.FLOAT_MAT4&&(o=4),e[a]={type:r.type,location:n.getAttribLocation(t,a),locationSize:o}}return e}function Po(n){return n!==""}function lf(n,t){let e=t.numSpotLightShadows+t.numSpotLightMaps-t.numSpotLightShadowsWithMaps;return n.replace(/NUM_DIR_LIGHTS/g,t.numDirLights).replace(/NUM_SPOT_LIGHTS/g,t.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,t.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,e).replace(/NUM_RECT_AREA_LIGHTS/g,t.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,t.numPointLights).replace(/NUM_HEMI_LIGHTS/g,t.numHemiLights).replace(/NUM_DIR_LIGHT_SHADOWS/g,t.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,t.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,t.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,t.numPointLightShadows)}function cf(n,t){return n.replace(/NUM_CLIPPING_PLANES/g,t.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,t.numClippingPlanes-t.numClipIntersection)}var vy=/^[ \t]*#include +<([\w\d./]+)>/gm;function Ch(n){return n.replace(vy,Ey)}var My=new Map;function Ey(n,t){let e=ne[t];if(e===void 0){let i=My.get(t);if(i!==void 0)e=ne[i],console.warn('THREE.WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',t,i);else throw new Error("Can not resolve #include <"+t+">")}return Ch(e)}var Sy=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function hf(n){return n.replace(Sy,wy)}function wy(n,t,e,i){let s="";for(let r=parseInt(t);r<parseInt(e);r++)s+=i.replace(/\[\s*i\s*\]/g,"[ "+r+" ]").replace(/UNROLLED_LOOP_INDEX/g,r);return s}function uf(n){let t=`precision ${n.precision} float;
	precision ${n.precision} int;
	precision ${n.precision} sampler2D;
	precision ${n.precision} samplerCube;
	precision ${n.precision} sampler3D;
	precision ${n.precision} sampler2DArray;
	precision ${n.precision} sampler2DShadow;
	precision ${n.precision} samplerCubeShadow;
	precision ${n.precision} sampler2DArrayShadow;
	precision ${n.precision} isampler2D;
	precision ${n.precision} isampler3D;
	precision ${n.precision} isamplerCube;
	precision ${n.precision} isampler2DArray;
	precision ${n.precision} usampler2D;
	precision ${n.precision} usampler3D;
	precision ${n.precision} usamplerCube;
	precision ${n.precision} usampler2DArray;
	`;return n.precision==="highp"?t+=`
#define HIGH_PRECISION`:n.precision==="mediump"?t+=`
#define MEDIUM_PRECISION`:n.precision==="lowp"&&(t+=`
#define LOW_PRECISION`),t}function Ty(n){let t="SHADOWMAP_TYPE_BASIC";return n.shadowMapType===jc?t="SHADOWMAP_TYPE_PCF":n.shadowMapType===Ka?t="SHADOWMAP_TYPE_PCF_SOFT":n.shadowMapType===oi&&(t="SHADOWMAP_TYPE_VSM"),t}function by(n){let t="ENVMAP_TYPE_CUBE";if(n.envMap)switch(n.envMapMode){case Ls:case Ds:t="ENVMAP_TYPE_CUBE";break;case So:t="ENVMAP_TYPE_CUBE_UV";break}return t}function Ay(n){let t="ENVMAP_MODE_REFLECTION";if(n.envMap)switch(n.envMapMode){case Ds:t="ENVMAP_MODE_REFRACTION";break}return t}function Ry(n){let t="ENVMAP_BLENDING_NONE";if(n.envMap)switch(n.combine){case rl:t="ENVMAP_BLENDING_MULTIPLY";break;case gd:t="ENVMAP_BLENDING_MIX";break;case xd:t="ENVMAP_BLENDING_ADD";break}return t}function Cy(n){let t=n.envMapCubeUVHeight;if(t===null)return null;let e=Math.log2(t)-2,i=1/t;return{texelWidth:1/(3*Math.max(Math.pow(2,e),112)),texelHeight:i,maxMip:e}}function Py(n,t,e,i){let s=n.getContext(),r=e.defines,a=e.vertexShader,o=e.fragmentShader,l=Ty(e),c=by(e),h=Ay(e),d=Ry(e),u=Cy(e),f=xy(e),x=yy(r),M=s.createProgram(),m,p,S=e.glslVersion?"#version "+e.glslVersion+`
`:"";e.isRawShaderMaterial?(m=["#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,x].filter(Po).join(`
`),m.length>0&&(m+=`
`),p=["#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,x].filter(Po).join(`
`),p.length>0&&(p+=`
`)):(m=[uf(e),"#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,x,e.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",e.batching?"#define USE_BATCHING":"",e.batchingColor?"#define USE_BATCHING_COLOR":"",e.instancing?"#define USE_INSTANCING":"",e.instancingColor?"#define USE_INSTANCING_COLOR":"",e.instancingMorph?"#define USE_INSTANCING_MORPH":"",e.useFog&&e.fog?"#define USE_FOG":"",e.useFog&&e.fogExp2?"#define FOG_EXP2":"",e.map?"#define USE_MAP":"",e.envMap?"#define USE_ENVMAP":"",e.envMap?"#define "+h:"",e.lightMap?"#define USE_LIGHTMAP":"",e.aoMap?"#define USE_AOMAP":"",e.bumpMap?"#define USE_BUMPMAP":"",e.normalMap?"#define USE_NORMALMAP":"",e.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",e.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",e.displacementMap?"#define USE_DISPLACEMENTMAP":"",e.emissiveMap?"#define USE_EMISSIVEMAP":"",e.anisotropy?"#define USE_ANISOTROPY":"",e.anisotropyMap?"#define USE_ANISOTROPYMAP":"",e.clearcoatMap?"#define USE_CLEARCOATMAP":"",e.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",e.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",e.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",e.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",e.specularMap?"#define USE_SPECULARMAP":"",e.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",e.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",e.roughnessMap?"#define USE_ROUGHNESSMAP":"",e.metalnessMap?"#define USE_METALNESSMAP":"",e.alphaMap?"#define USE_ALPHAMAP":"",e.alphaHash?"#define USE_ALPHAHASH":"",e.transmission?"#define USE_TRANSMISSION":"",e.transmissionMap?"#define USE_TRANSMISSIONMAP":"",e.thicknessMap?"#define USE_THICKNESSMAP":"",e.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",e.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",e.mapUv?"#define MAP_UV "+e.mapUv:"",e.alphaMapUv?"#define ALPHAMAP_UV "+e.alphaMapUv:"",e.lightMapUv?"#define LIGHTMAP_UV "+e.lightMapUv:"",e.aoMapUv?"#define AOMAP_UV "+e.aoMapUv:"",e.emissiveMapUv?"#define EMISSIVEMAP_UV "+e.emissiveMapUv:"",e.bumpMapUv?"#define BUMPMAP_UV "+e.bumpMapUv:"",e.normalMapUv?"#define NORMALMAP_UV "+e.normalMapUv:"",e.displacementMapUv?"#define DISPLACEMENTMAP_UV "+e.displacementMapUv:"",e.metalnessMapUv?"#define METALNESSMAP_UV "+e.metalnessMapUv:"",e.roughnessMapUv?"#define ROUGHNESSMAP_UV "+e.roughnessMapUv:"",e.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+e.anisotropyMapUv:"",e.clearcoatMapUv?"#define CLEARCOATMAP_UV "+e.clearcoatMapUv:"",e.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+e.clearcoatNormalMapUv:"",e.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+e.clearcoatRoughnessMapUv:"",e.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+e.iridescenceMapUv:"",e.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+e.iridescenceThicknessMapUv:"",e.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+e.sheenColorMapUv:"",e.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+e.sheenRoughnessMapUv:"",e.specularMapUv?"#define SPECULARMAP_UV "+e.specularMapUv:"",e.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+e.specularColorMapUv:"",e.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+e.specularIntensityMapUv:"",e.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+e.transmissionMapUv:"",e.thicknessMapUv?"#define THICKNESSMAP_UV "+e.thicknessMapUv:"",e.vertexTangents&&e.flatShading===!1?"#define USE_TANGENT":"",e.vertexColors?"#define USE_COLOR":"",e.vertexAlphas?"#define USE_COLOR_ALPHA":"",e.vertexUv1s?"#define USE_UV1":"",e.vertexUv2s?"#define USE_UV2":"",e.vertexUv3s?"#define USE_UV3":"",e.pointsUvs?"#define USE_POINTS_UV":"",e.flatShading?"#define FLAT_SHADED":"",e.skinning?"#define USE_SKINNING":"",e.morphTargets?"#define USE_MORPHTARGETS":"",e.morphNormals&&e.flatShading===!1?"#define USE_MORPHNORMALS":"",e.morphColors?"#define USE_MORPHCOLORS":"",e.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+e.morphTextureStride:"",e.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+e.morphTargetsCount:"",e.doubleSided?"#define DOUBLE_SIDED":"",e.flipSided?"#define FLIP_SIDED":"",e.shadowMapEnabled?"#define USE_SHADOWMAP":"",e.shadowMapEnabled?"#define "+l:"",e.sizeAttenuation?"#define USE_SIZEATTENUATION":"",e.numLightProbes>0?"#define USE_LIGHT_PROBES":"",e.logarithmicDepthBuffer?"#define USE_LOGDEPTHBUF":"",e.reverseDepthBuffer?"#define USE_REVERSEDEPTHBUF":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter(Po).join(`
`),p=[uf(e),"#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,x,e.useFog&&e.fog?"#define USE_FOG":"",e.useFog&&e.fogExp2?"#define FOG_EXP2":"",e.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",e.map?"#define USE_MAP":"",e.matcap?"#define USE_MATCAP":"",e.envMap?"#define USE_ENVMAP":"",e.envMap?"#define "+c:"",e.envMap?"#define "+h:"",e.envMap?"#define "+d:"",u?"#define CUBEUV_TEXEL_WIDTH "+u.texelWidth:"",u?"#define CUBEUV_TEXEL_HEIGHT "+u.texelHeight:"",u?"#define CUBEUV_MAX_MIP "+u.maxMip+".0":"",e.lightMap?"#define USE_LIGHTMAP":"",e.aoMap?"#define USE_AOMAP":"",e.bumpMap?"#define USE_BUMPMAP":"",e.normalMap?"#define USE_NORMALMAP":"",e.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",e.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",e.emissiveMap?"#define USE_EMISSIVEMAP":"",e.anisotropy?"#define USE_ANISOTROPY":"",e.anisotropyMap?"#define USE_ANISOTROPYMAP":"",e.clearcoat?"#define USE_CLEARCOAT":"",e.clearcoatMap?"#define USE_CLEARCOATMAP":"",e.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",e.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",e.dispersion?"#define USE_DISPERSION":"",e.iridescence?"#define USE_IRIDESCENCE":"",e.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",e.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",e.specularMap?"#define USE_SPECULARMAP":"",e.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",e.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",e.roughnessMap?"#define USE_ROUGHNESSMAP":"",e.metalnessMap?"#define USE_METALNESSMAP":"",e.alphaMap?"#define USE_ALPHAMAP":"",e.alphaTest?"#define USE_ALPHATEST":"",e.alphaHash?"#define USE_ALPHAHASH":"",e.sheen?"#define USE_SHEEN":"",e.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",e.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",e.transmission?"#define USE_TRANSMISSION":"",e.transmissionMap?"#define USE_TRANSMISSIONMAP":"",e.thicknessMap?"#define USE_THICKNESSMAP":"",e.vertexTangents&&e.flatShading===!1?"#define USE_TANGENT":"",e.vertexColors||e.instancingColor||e.batchingColor?"#define USE_COLOR":"",e.vertexAlphas?"#define USE_COLOR_ALPHA":"",e.vertexUv1s?"#define USE_UV1":"",e.vertexUv2s?"#define USE_UV2":"",e.vertexUv3s?"#define USE_UV3":"",e.pointsUvs?"#define USE_POINTS_UV":"",e.gradientMap?"#define USE_GRADIENTMAP":"",e.flatShading?"#define FLAT_SHADED":"",e.doubleSided?"#define DOUBLE_SIDED":"",e.flipSided?"#define FLIP_SIDED":"",e.shadowMapEnabled?"#define USE_SHADOWMAP":"",e.shadowMapEnabled?"#define "+l:"",e.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",e.numLightProbes>0?"#define USE_LIGHT_PROBES":"",e.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",e.decodeVideoTextureEmissive?"#define DECODE_VIDEO_TEXTURE_EMISSIVE":"",e.logarithmicDepthBuffer?"#define USE_LOGDEPTHBUF":"",e.reverseDepthBuffer?"#define USE_REVERSEDEPTHBUF":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",e.toneMapping!==Ci?"#define TONE_MAPPING":"",e.toneMapping!==Ci?ne.tonemapping_pars_fragment:"",e.toneMapping!==Ci?my("toneMapping",e.toneMapping):"",e.dithering?"#define DITHERING":"",e.opaque?"#define OPAQUE":"",ne.colorspace_pars_fragment,py("linearToOutputTexel",e.outputColorSpace),gy(),e.useDepthPacking?"#define DEPTH_PACKING "+e.depthPacking:"",`
`].filter(Po).join(`
`)),a=Ch(a),a=lf(a,e),a=cf(a,e),o=Ch(o),o=lf(o,e),o=cf(o,e),a=hf(a),o=hf(o),e.isRawShaderMaterial!==!0&&(S=`#version 300 es
`,m=[f,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+m,p=["#define varying in",e.glslVersion===fh?"":"layout(location = 0) out highp vec4 pc_fragColor;",e.glslVersion===fh?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+p);let E=S+m+a,g=S+p+o,C=rf(s,s.VERTEX_SHADER,E),A=rf(s,s.FRAGMENT_SHADER,g);s.attachShader(M,C),s.attachShader(M,A),e.index0AttributeName!==void 0?s.bindAttribLocation(M,0,e.index0AttributeName):e.morphTargets===!0&&s.bindAttribLocation(M,0,"position"),s.linkProgram(M);function _(w){if(n.debug.checkShaderErrors){let P=s.getProgramInfoLog(M).trim(),D=s.getShaderInfoLog(C).trim(),N=s.getShaderInfoLog(A).trim(),H=!0,U=!0;if(s.getProgramParameter(M,s.LINK_STATUS)===!1)if(H=!1,typeof n.debug.onShaderError=="function")n.debug.onShaderError(s,M,C,A);else{let k=af(s,C,"vertex"),F=af(s,A,"fragment");console.error("THREE.WebGLProgram: Shader Error "+s.getError()+" - VALIDATE_STATUS "+s.getProgramParameter(M,s.VALIDATE_STATUS)+`

Material Name: `+w.name+`
Material Type: `+w.type+`

Program Info Log: `+P+`
`+k+`
`+F)}else P!==""?console.warn("THREE.WebGLProgram: Program Info Log:",P):(D===""||N==="")&&(U=!1);U&&(w.diagnostics={runnable:H,programLog:P,vertexShader:{log:D,prefix:m},fragmentShader:{log:N,prefix:p}})}s.deleteShader(C),s.deleteShader(A),T=new wr(s,M),v=_y(s,M)}let T;this.getUniforms=function(){return T===void 0&&_(this),T};let v;this.getAttributes=function(){return v===void 0&&_(this),v};let y=e.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return y===!1&&(y=s.getProgramParameter(M,hy)),y},this.destroy=function(){i.releaseStatesOfProgram(this),s.deleteProgram(M),this.program=void 0},this.type=e.shaderType,this.name=e.shaderName,this.id=uy++,this.cacheKey=t,this.usedTimes=1,this.program=M,this.vertexShader=C,this.fragmentShader=A,this}var Iy=0,Ph=class{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(t){let e=t.vertexShader,i=t.fragmentShader,s=this._getShaderStage(e),r=this._getShaderStage(i),a=this._getShaderCacheForMaterial(t);return a.has(s)===!1&&(a.add(s),s.usedTimes++),a.has(r)===!1&&(a.add(r),r.usedTimes++),this}remove(t){let e=this.materialCache.get(t);for(let i of e)i.usedTimes--,i.usedTimes===0&&this.shaderCache.delete(i.code);return this.materialCache.delete(t),this}getVertexShaderID(t){return this._getShaderStage(t.vertexShader).id}getFragmentShaderID(t){return this._getShaderStage(t.fragmentShader).id}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(t){let e=this.materialCache,i=e.get(t);return i===void 0&&(i=new Set,e.set(t,i)),i}_getShaderStage(t){let e=this.shaderCache,i=e.get(t);return i===void 0&&(i=new Ih(t),e.set(t,i)),i}},Ih=class{constructor(t){this.id=Iy++,this.code=t,this.usedTimes=0}};function Ly(n,t,e,i,s,r,a){let o=new Kr,l=new Ph,c=new Set,h=[],d=s.logarithmicDepthBuffer,u=s.vertexTextures,f=s.precision,x={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distanceRGBA",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function M(v){return c.add(v),v===0?"uv":`uv${v}`}function m(v,y,w,P,D){let N=P.fog,H=D.geometry,U=v.isMeshStandardMaterial?P.environment:null,k=(v.isMeshStandardMaterial?e:t).get(v.envMap||U),F=k&&k.mapping===So?k.image.height:null,G=x[v.type];v.precision!==null&&(f=s.getMaxPrecision(v.precision),f!==v.precision&&console.warn("THREE.WebGLProgram.getParameters:",v.precision,"not supported, using",f,"instead."));let q=H.morphAttributes.position||H.morphAttributes.normal||H.morphAttributes.color,et=q!==void 0?q.length:0,nt=0;H.morphAttributes.position!==void 0&&(nt=1),H.morphAttributes.normal!==void 0&&(nt=2),H.morphAttributes.color!==void 0&&(nt=3);let rt,B,Z,ct;if(G){let ve=li[G];rt=ve.vertexShader,B=ve.fragmentShader}else rt=v.vertexShader,B=v.fragmentShader,l.update(v),Z=l.getVertexShaderID(v),ct=l.getFragmentShaderID(v);let z=n.getRenderTarget(),j=n.state.buffers.depth.getReversed(),ft=D.isInstancedMesh===!0,dt=D.isBatchedMesh===!0,Ct=!!v.map,Q=!!v.matcap,ht=!!k,L=!!v.aoMap,Nt=!!v.lightMap,pt=!!v.bumpMap,At=!!v.normalMap,xt=!!v.displacementMap,Wt=!!v.emissiveMap,wt=!!v.metalnessMap,I=!!v.roughnessMap,b=v.anisotropy>0,Y=v.clearcoat>0,it=v.dispersion>0,ut=v.iridescence>0,st=v.sheen>0,Ut=v.transmission>0,vt=b&&!!v.anisotropyMap,bt=Y&&!!v.clearcoatMap,ce=Y&&!!v.clearcoatNormalMap,gt=Y&&!!v.clearcoatRoughnessMap,Pt=ut&&!!v.iridescenceMap,Gt=ut&&!!v.iridescenceThicknessMap,Yt=st&&!!v.sheenColorMap,It=st&&!!v.sheenRoughnessMap,ue=!!v.specularMap,ee=!!v.specularColorMap,Te=!!v.specularIntensityMap,V=Ut&&!!v.transmissionMap,Mt=Ut&&!!v.thicknessMap,tt=!!v.gradientMap,ot=!!v.alphaMap,Tt=v.alphaTest>0,St=!!v.alphaHash,jt=!!v.extensions,Ne=Ci;v.toneMapped&&(z===null||z.isXRRenderTarget===!0)&&(Ne=n.toneMapping);let nn={shaderID:G,shaderType:v.type,shaderName:v.name,vertexShader:rt,fragmentShader:B,defines:v.defines,customVertexShaderID:Z,customFragmentShaderID:ct,isRawShaderMaterial:v.isRawShaderMaterial===!0,glslVersion:v.glslVersion,precision:f,batching:dt,batchingColor:dt&&D._colorsTexture!==null,instancing:ft,instancingColor:ft&&D.instanceColor!==null,instancingMorph:ft&&D.morphTexture!==null,supportsVertexTextures:u,outputColorSpace:z===null?n.outputColorSpace:z.isXRRenderTarget===!0?z.texture.colorSpace:As,alphaToCoverage:!!v.alphaToCoverage,map:Ct,matcap:Q,envMap:ht,envMapMode:ht&&k.mapping,envMapCubeUVHeight:F,aoMap:L,lightMap:Nt,bumpMap:pt,normalMap:At,displacementMap:u&&xt,emissiveMap:Wt,normalMapObjectSpace:At&&v.normalMapType===Ad,normalMapTangentSpace:At&&v.normalMapType===Vl,metalnessMap:wt,roughnessMap:I,anisotropy:b,anisotropyMap:vt,clearcoat:Y,clearcoatMap:bt,clearcoatNormalMap:ce,clearcoatRoughnessMap:gt,dispersion:it,iridescence:ut,iridescenceMap:Pt,iridescenceThicknessMap:Gt,sheen:st,sheenColorMap:Yt,sheenRoughnessMap:It,specularMap:ue,specularColorMap:ee,specularIntensityMap:Te,transmission:Ut,transmissionMap:V,thicknessMap:Mt,gradientMap:tt,opaque:v.transparent===!1&&v.blending===ws&&v.alphaToCoverage===!1,alphaMap:ot,alphaTest:Tt,alphaHash:St,combine:v.combine,mapUv:Ct&&M(v.map.channel),aoMapUv:L&&M(v.aoMap.channel),lightMapUv:Nt&&M(v.lightMap.channel),bumpMapUv:pt&&M(v.bumpMap.channel),normalMapUv:At&&M(v.normalMap.channel),displacementMapUv:xt&&M(v.displacementMap.channel),emissiveMapUv:Wt&&M(v.emissiveMap.channel),metalnessMapUv:wt&&M(v.metalnessMap.channel),roughnessMapUv:I&&M(v.roughnessMap.channel),anisotropyMapUv:vt&&M(v.anisotropyMap.channel),clearcoatMapUv:bt&&M(v.clearcoatMap.channel),clearcoatNormalMapUv:ce&&M(v.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:gt&&M(v.clearcoatRoughnessMap.channel),iridescenceMapUv:Pt&&M(v.iridescenceMap.channel),iridescenceThicknessMapUv:Gt&&M(v.iridescenceThicknessMap.channel),sheenColorMapUv:Yt&&M(v.sheenColorMap.channel),sheenRoughnessMapUv:It&&M(v.sheenRoughnessMap.channel),specularMapUv:ue&&M(v.specularMap.channel),specularColorMapUv:ee&&M(v.specularColorMap.channel),specularIntensityMapUv:Te&&M(v.specularIntensityMap.channel),transmissionMapUv:V&&M(v.transmissionMap.channel),thicknessMapUv:Mt&&M(v.thicknessMap.channel),alphaMapUv:ot&&M(v.alphaMap.channel),vertexTangents:!!H.attributes.tangent&&(At||b),vertexColors:v.vertexColors,vertexAlphas:v.vertexColors===!0&&!!H.attributes.color&&H.attributes.color.itemSize===4,pointsUvs:D.isPoints===!0&&!!H.attributes.uv&&(Ct||ot),fog:!!N,useFog:v.fog===!0,fogExp2:!!N&&N.isFogExp2,flatShading:v.flatShading===!0,sizeAttenuation:v.sizeAttenuation===!0,logarithmicDepthBuffer:d,reverseDepthBuffer:j,skinning:D.isSkinnedMesh===!0,morphTargets:H.morphAttributes.position!==void 0,morphNormals:H.morphAttributes.normal!==void 0,morphColors:H.morphAttributes.color!==void 0,morphTargetsCount:et,morphTextureStride:nt,numDirLights:y.directional.length,numPointLights:y.point.length,numSpotLights:y.spot.length,numSpotLightMaps:y.spotLightMap.length,numRectAreaLights:y.rectArea.length,numHemiLights:y.hemi.length,numDirLightShadows:y.directionalShadowMap.length,numPointLightShadows:y.pointShadowMap.length,numSpotLightShadows:y.spotShadowMap.length,numSpotLightShadowsWithMaps:y.numSpotLightShadowsWithMaps,numLightProbes:y.numLightProbes,numClippingPlanes:a.numPlanes,numClipIntersection:a.numIntersection,dithering:v.dithering,shadowMapEnabled:n.shadowMap.enabled&&w.length>0,shadowMapType:n.shadowMap.type,toneMapping:Ne,decodeVideoTexture:Ct&&v.map.isVideoTexture===!0&&pe.getTransfer(v.map.colorSpace)===Me,decodeVideoTextureEmissive:Wt&&v.emissiveMap.isVideoTexture===!0&&pe.getTransfer(v.emissiveMap.colorSpace)===Me,premultipliedAlpha:v.premultipliedAlpha,doubleSided:v.side===Ce,flipSided:v.side===je,useDepthPacking:v.depthPacking>=0,depthPacking:v.depthPacking||0,index0AttributeName:v.index0AttributeName,extensionClipCullDistance:jt&&v.extensions.clipCullDistance===!0&&i.has("WEBGL_clip_cull_distance"),extensionMultiDraw:(jt&&v.extensions.multiDraw===!0||dt)&&i.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:i.has("KHR_parallel_shader_compile"),customProgramCacheKey:v.customProgramCacheKey()};return nn.vertexUv1s=c.has(1),nn.vertexUv2s=c.has(2),nn.vertexUv3s=c.has(3),c.clear(),nn}function p(v){let y=[];if(v.shaderID?y.push(v.shaderID):(y.push(v.customVertexShaderID),y.push(v.customFragmentShaderID)),v.defines!==void 0)for(let w in v.defines)y.push(w),y.push(v.defines[w]);return v.isRawShaderMaterial===!1&&(S(y,v),E(y,v),y.push(n.outputColorSpace)),y.push(v.customProgramCacheKey),y.join()}function S(v,y){v.push(y.precision),v.push(y.outputColorSpace),v.push(y.envMapMode),v.push(y.envMapCubeUVHeight),v.push(y.mapUv),v.push(y.alphaMapUv),v.push(y.lightMapUv),v.push(y.aoMapUv),v.push(y.bumpMapUv),v.push(y.normalMapUv),v.push(y.displacementMapUv),v.push(y.emissiveMapUv),v.push(y.metalnessMapUv),v.push(y.roughnessMapUv),v.push(y.anisotropyMapUv),v.push(y.clearcoatMapUv),v.push(y.clearcoatNormalMapUv),v.push(y.clearcoatRoughnessMapUv),v.push(y.iridescenceMapUv),v.push(y.iridescenceThicknessMapUv),v.push(y.sheenColorMapUv),v.push(y.sheenRoughnessMapUv),v.push(y.specularMapUv),v.push(y.specularColorMapUv),v.push(y.specularIntensityMapUv),v.push(y.transmissionMapUv),v.push(y.thicknessMapUv),v.push(y.combine),v.push(y.fogExp2),v.push(y.sizeAttenuation),v.push(y.morphTargetsCount),v.push(y.morphAttributeCount),v.push(y.numDirLights),v.push(y.numPointLights),v.push(y.numSpotLights),v.push(y.numSpotLightMaps),v.push(y.numHemiLights),v.push(y.numRectAreaLights),v.push(y.numDirLightShadows),v.push(y.numPointLightShadows),v.push(y.numSpotLightShadows),v.push(y.numSpotLightShadowsWithMaps),v.push(y.numLightProbes),v.push(y.shadowMapType),v.push(y.toneMapping),v.push(y.numClippingPlanes),v.push(y.numClipIntersection),v.push(y.depthPacking)}function E(v,y){o.disableAll(),y.supportsVertexTextures&&o.enable(0),y.instancing&&o.enable(1),y.instancingColor&&o.enable(2),y.instancingMorph&&o.enable(3),y.matcap&&o.enable(4),y.envMap&&o.enable(5),y.normalMapObjectSpace&&o.enable(6),y.normalMapTangentSpace&&o.enable(7),y.clearcoat&&o.enable(8),y.iridescence&&o.enable(9),y.alphaTest&&o.enable(10),y.vertexColors&&o.enable(11),y.vertexAlphas&&o.enable(12),y.vertexUv1s&&o.enable(13),y.vertexUv2s&&o.enable(14),y.vertexUv3s&&o.enable(15),y.vertexTangents&&o.enable(16),y.anisotropy&&o.enable(17),y.alphaHash&&o.enable(18),y.batching&&o.enable(19),y.dispersion&&o.enable(20),y.batchingColor&&o.enable(21),v.push(o.mask),o.disableAll(),y.fog&&o.enable(0),y.useFog&&o.enable(1),y.flatShading&&o.enable(2),y.logarithmicDepthBuffer&&o.enable(3),y.reverseDepthBuffer&&o.enable(4),y.skinning&&o.enable(5),y.morphTargets&&o.enable(6),y.morphNormals&&o.enable(7),y.morphColors&&o.enable(8),y.premultipliedAlpha&&o.enable(9),y.shadowMapEnabled&&o.enable(10),y.doubleSided&&o.enable(11),y.flipSided&&o.enable(12),y.useDepthPacking&&o.enable(13),y.dithering&&o.enable(14),y.transmission&&o.enable(15),y.sheen&&o.enable(16),y.opaque&&o.enable(17),y.pointsUvs&&o.enable(18),y.decodeVideoTexture&&o.enable(19),y.decodeVideoTextureEmissive&&o.enable(20),y.alphaToCoverage&&o.enable(21),v.push(o.mask)}function g(v){let y=x[v.type],w;if(y){let P=li[y];w=kd.clone(P.uniforms)}else w=v.uniforms;return w}function C(v,y){let w;for(let P=0,D=h.length;P<D;P++){let N=h[P];if(N.cacheKey===y){w=N,++w.usedTimes;break}}return w===void 0&&(w=new Py(n,y,v,r),h.push(w)),w}function A(v){if(--v.usedTimes===0){let y=h.indexOf(v);h[y]=h[h.length-1],h.pop(),v.destroy()}}function _(v){l.remove(v)}function T(){l.dispose()}return{getParameters:m,getProgramCacheKey:p,getUniforms:g,acquireProgram:C,releaseProgram:A,releaseShaderCache:_,programs:h,dispose:T}}function Dy(){let n=new WeakMap;function t(a){return n.has(a)}function e(a){let o=n.get(a);return o===void 0&&(o={},n.set(a,o)),o}function i(a){n.delete(a)}function s(a,o,l){n.get(a)[o]=l}function r(){n=new WeakMap}return{has:t,get:e,remove:i,update:s,dispose:r}}function Uy(n,t){return n.groupOrder!==t.groupOrder?n.groupOrder-t.groupOrder:n.renderOrder!==t.renderOrder?n.renderOrder-t.renderOrder:n.material.id!==t.material.id?n.material.id-t.material.id:n.z!==t.z?n.z-t.z:n.id-t.id}function df(n,t){return n.groupOrder!==t.groupOrder?n.groupOrder-t.groupOrder:n.renderOrder!==t.renderOrder?n.renderOrder-t.renderOrder:n.z!==t.z?t.z-n.z:n.id-t.id}function ff(){let n=[],t=0,e=[],i=[],s=[];function r(){t=0,e.length=0,i.length=0,s.length=0}function a(d,u,f,x,M,m){let p=n[t];return p===void 0?(p={id:d.id,object:d,geometry:u,material:f,groupOrder:x,renderOrder:d.renderOrder,z:M,group:m},n[t]=p):(p.id=d.id,p.object=d,p.geometry=u,p.material=f,p.groupOrder=x,p.renderOrder=d.renderOrder,p.z=M,p.group=m),t++,p}function o(d,u,f,x,M,m){let p=a(d,u,f,x,M,m);f.transmission>0?i.push(p):f.transparent===!0?s.push(p):e.push(p)}function l(d,u,f,x,M,m){let p=a(d,u,f,x,M,m);f.transmission>0?i.unshift(p):f.transparent===!0?s.unshift(p):e.unshift(p)}function c(d,u){e.length>1&&e.sort(d||Uy),i.length>1&&i.sort(u||df),s.length>1&&s.sort(u||df)}function h(){for(let d=t,u=n.length;d<u;d++){let f=n[d];if(f.id===null)break;f.id=null,f.object=null,f.geometry=null,f.material=null,f.group=null}}return{opaque:e,transmissive:i,transparent:s,init:r,push:o,unshift:l,finish:h,sort:c}}function Ny(){let n=new WeakMap;function t(i,s){let r=n.get(i),a;return r===void 0?(a=new ff,n.set(i,[a])):s>=r.length?(a=new ff,r.push(a)):a=r[s],a}function e(){n=new WeakMap}return{get:t,dispose:e}}function Fy(){let n={};return{get:function(t){if(n[t.id]!==void 0)return n[t.id];let e;switch(t.type){case"DirectionalLight":e={direction:new O,color:new Ot};break;case"SpotLight":e={position:new O,direction:new O,color:new Ot,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":e={position:new O,color:new Ot,distance:0,decay:0};break;case"HemisphereLight":e={direction:new O,skyColor:new Ot,groundColor:new Ot};break;case"RectAreaLight":e={color:new Ot,position:new O,halfWidth:new O,halfHeight:new O};break}return n[t.id]=e,e}}}function Oy(){let n={};return{get:function(t){if(n[t.id]!==void 0)return n[t.id];let e;switch(t.type){case"DirectionalLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new at};break;case"SpotLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new at};break;case"PointLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new at,shadowCameraNear:1,shadowCameraFar:1e3};break}return n[t.id]=e,e}}}var Hy=0;function By(n,t){return(t.castShadow?2:0)-(n.castShadow?2:0)+(t.map?1:0)-(n.map?1:0)}function ky(n){let t=new Fy,e=Oy(),i={version:0,hash:{directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let c=0;c<9;c++)i.probe.push(new O);let s=new O,r=new be,a=new be;function o(c){let h=0,d=0,u=0;for(let v=0;v<9;v++)i.probe[v].set(0,0,0);let f=0,x=0,M=0,m=0,p=0,S=0,E=0,g=0,C=0,A=0,_=0;c.sort(By);for(let v=0,y=c.length;v<y;v++){let w=c[v],P=w.color,D=w.intensity,N=w.distance,H=w.shadow&&w.shadow.map?w.shadow.map.texture:null;if(w.isAmbientLight)h+=P.r*D,d+=P.g*D,u+=P.b*D;else if(w.isLightProbe){for(let U=0;U<9;U++)i.probe[U].addScaledVector(w.sh.coefficients[U],D);_++}else if(w.isDirectionalLight){let U=t.get(w);if(U.color.copy(w.color).multiplyScalar(w.intensity),w.castShadow){let k=w.shadow,F=e.get(w);F.shadowIntensity=k.intensity,F.shadowBias=k.bias,F.shadowNormalBias=k.normalBias,F.shadowRadius=k.radius,F.shadowMapSize=k.mapSize,i.directionalShadow[f]=F,i.directionalShadowMap[f]=H,i.directionalShadowMatrix[f]=w.shadow.matrix,S++}i.directional[f]=U,f++}else if(w.isSpotLight){let U=t.get(w);U.position.setFromMatrixPosition(w.matrixWorld),U.color.copy(P).multiplyScalar(D),U.distance=N,U.coneCos=Math.cos(w.angle),U.penumbraCos=Math.cos(w.angle*(1-w.penumbra)),U.decay=w.decay,i.spot[M]=U;let k=w.shadow;if(w.map&&(i.spotLightMap[C]=w.map,C++,k.updateMatrices(w),w.castShadow&&A++),i.spotLightMatrix[M]=k.matrix,w.castShadow){let F=e.get(w);F.shadowIntensity=k.intensity,F.shadowBias=k.bias,F.shadowNormalBias=k.normalBias,F.shadowRadius=k.radius,F.shadowMapSize=k.mapSize,i.spotShadow[M]=F,i.spotShadowMap[M]=H,g++}M++}else if(w.isRectAreaLight){let U=t.get(w);U.color.copy(P).multiplyScalar(D),U.halfWidth.set(w.width*.5,0,0),U.halfHeight.set(0,w.height*.5,0),i.rectArea[m]=U,m++}else if(w.isPointLight){let U=t.get(w);if(U.color.copy(w.color).multiplyScalar(w.intensity),U.distance=w.distance,U.decay=w.decay,w.castShadow){let k=w.shadow,F=e.get(w);F.shadowIntensity=k.intensity,F.shadowBias=k.bias,F.shadowNormalBias=k.normalBias,F.shadowRadius=k.radius,F.shadowMapSize=k.mapSize,F.shadowCameraNear=k.camera.near,F.shadowCameraFar=k.camera.far,i.pointShadow[x]=F,i.pointShadowMap[x]=H,i.pointShadowMatrix[x]=w.shadow.matrix,E++}i.point[x]=U,x++}else if(w.isHemisphereLight){let U=t.get(w);U.skyColor.copy(w.color).multiplyScalar(D),U.groundColor.copy(w.groundColor).multiplyScalar(D),i.hemi[p]=U,p++}}m>0&&(n.has("OES_texture_float_linear")===!0?(i.rectAreaLTC1=_t.LTC_FLOAT_1,i.rectAreaLTC2=_t.LTC_FLOAT_2):(i.rectAreaLTC1=_t.LTC_HALF_1,i.rectAreaLTC2=_t.LTC_HALF_2)),i.ambient[0]=h,i.ambient[1]=d,i.ambient[2]=u;let T=i.hash;(T.directionalLength!==f||T.pointLength!==x||T.spotLength!==M||T.rectAreaLength!==m||T.hemiLength!==p||T.numDirectionalShadows!==S||T.numPointShadows!==E||T.numSpotShadows!==g||T.numSpotMaps!==C||T.numLightProbes!==_)&&(i.directional.length=f,i.spot.length=M,i.rectArea.length=m,i.point.length=x,i.hemi.length=p,i.directionalShadow.length=S,i.directionalShadowMap.length=S,i.pointShadow.length=E,i.pointShadowMap.length=E,i.spotShadow.length=g,i.spotShadowMap.length=g,i.directionalShadowMatrix.length=S,i.pointShadowMatrix.length=E,i.spotLightMatrix.length=g+C-A,i.spotLightMap.length=C,i.numSpotLightShadowsWithMaps=A,i.numLightProbes=_,T.directionalLength=f,T.pointLength=x,T.spotLength=M,T.rectAreaLength=m,T.hemiLength=p,T.numDirectionalShadows=S,T.numPointShadows=E,T.numSpotShadows=g,T.numSpotMaps=C,T.numLightProbes=_,i.version=Hy++)}function l(c,h){let d=0,u=0,f=0,x=0,M=0,m=h.matrixWorldInverse;for(let p=0,S=c.length;p<S;p++){let E=c[p];if(E.isDirectionalLight){let g=i.directional[d];g.direction.setFromMatrixPosition(E.matrixWorld),s.setFromMatrixPosition(E.target.matrixWorld),g.direction.sub(s),g.direction.transformDirection(m),d++}else if(E.isSpotLight){let g=i.spot[f];g.position.setFromMatrixPosition(E.matrixWorld),g.position.applyMatrix4(m),g.direction.setFromMatrixPosition(E.matrixWorld),s.setFromMatrixPosition(E.target.matrixWorld),g.direction.sub(s),g.direction.transformDirection(m),f++}else if(E.isRectAreaLight){let g=i.rectArea[x];g.position.setFromMatrixPosition(E.matrixWorld),g.position.applyMatrix4(m),a.identity(),r.copy(E.matrixWorld),r.premultiply(m),a.extractRotation(r),g.halfWidth.set(E.width*.5,0,0),g.halfHeight.set(0,E.height*.5,0),g.halfWidth.applyMatrix4(a),g.halfHeight.applyMatrix4(a),x++}else if(E.isPointLight){let g=i.point[u];g.position.setFromMatrixPosition(E.matrixWorld),g.position.applyMatrix4(m),u++}else if(E.isHemisphereLight){let g=i.hemi[M];g.direction.setFromMatrixPosition(E.matrixWorld),g.direction.transformDirection(m),M++}}}return{setup:o,setupView:l,state:i}}function pf(n){let t=new ky(n),e=[],i=[];function s(h){c.camera=h,e.length=0,i.length=0}function r(h){e.push(h)}function a(h){i.push(h)}function o(){t.setup(e)}function l(h){t.setupView(e,h)}let c={lightsArray:e,shadowsArray:i,camera:null,lights:t,transmissionRenderTarget:{}};return{init:s,state:c,setupLights:o,setupLightsView:l,pushLight:r,pushShadow:a}}function zy(n){let t=new WeakMap;function e(s,r=0){let a=t.get(s),o;return a===void 0?(o=new pf(n),t.set(s,[o])):r>=a.length?(o=new pf(n),a.push(o)):o=a[r],o}function i(){t=new WeakMap}return{get:e,dispose:i}}var Gy=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,Vy=`uniform sampler2D shadow_pass;
uniform vec2 resolution;
uniform float radius;
#include <packing>
void main() {
	const float samples = float( VSM_SAMPLES );
	float mean = 0.0;
	float squared_mean = 0.0;
	float uvStride = samples <= 1.0 ? 0.0 : 2.0 / ( samples - 1.0 );
	float uvStart = samples <= 1.0 ? 0.0 : - 1.0;
	for ( float i = 0.0; i < samples; i ++ ) {
		float uvOffset = uvStart + i * uvStride;
		#ifdef HORIZONTAL_PASS
			vec2 distribution = unpackRGBATo2Half( texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( uvOffset, 0.0 ) * radius ) / resolution ) );
			mean += distribution.x;
			squared_mean += distribution.y * distribution.y + distribution.x * distribution.x;
		#else
			float depth = unpackRGBAToDepth( texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( 0.0, uvOffset ) * radius ) / resolution ) );
			mean += depth;
			squared_mean += depth * depth;
		#endif
	}
	mean = mean / samples;
	squared_mean = squared_mean / samples;
	float std_dev = sqrt( squared_mean - mean * mean );
	gl_FragColor = pack2HalfToRGBA( vec2( mean, std_dev ) );
}`;function Wy(n,t,e){let i=new fr,s=new at,r=new at,a=new Le,o=new Ba({depthPacking:bd}),l=new ka,c={},h=e.maxTextureSize,d={[Si]:je,[je]:Si,[Ce]:Ce},u=new qn({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new at},radius:{value:4}},vertexShader:Gy,fragmentShader:Vy}),f=u.clone();f.defines.HORIZONTAL_PASS=1;let x=new qe;x.setAttribute("position",new gn(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));let M=new $(x,u),m=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=jc;let p=this.type;this.render=function(A,_,T){if(m.enabled===!1||m.autoUpdate===!1&&m.needsUpdate===!1||A.length===0)return;let v=n.getRenderTarget(),y=n.getActiveCubeFace(),w=n.getActiveMipmapLevel(),P=n.state;P.setBlending(Ri),P.buffers.color.setClear(1,1,1,1),P.buffers.depth.setTest(!0),P.setScissorTest(!1);let D=p!==oi&&this.type===oi,N=p===oi&&this.type!==oi;for(let H=0,U=A.length;H<U;H++){let k=A[H],F=k.shadow;if(F===void 0){console.warn("THREE.WebGLShadowMap:",k,"has no shadow.");continue}if(F.autoUpdate===!1&&F.needsUpdate===!1)continue;s.copy(F.mapSize);let G=F.getFrameExtents();if(s.multiply(G),r.copy(F.mapSize),(s.x>h||s.y>h)&&(s.x>h&&(r.x=Math.floor(h/G.x),s.x=r.x*G.x,F.mapSize.x=r.x),s.y>h&&(r.y=Math.floor(h/G.y),s.y=r.y*G.y,F.mapSize.y=r.y)),F.map===null||D===!0||N===!0){let et=this.type!==oi?{minFilter:xn,magFilter:xn}:{};F.map!==null&&F.map.dispose(),F.map=new ni(s.x,s.y,et),F.map.texture.name=k.name+".shadowMap",F.camera.updateProjectionMatrix()}n.setRenderTarget(F.map),n.clear();let q=F.getViewportCount();for(let et=0;et<q;et++){let nt=F.getViewport(et);a.set(r.x*nt.x,r.y*nt.y,r.x*nt.z,r.y*nt.w),P.viewport(a),F.updateMatrices(k,et),i=F.getFrustum(),g(_,T,F.camera,k,this.type)}F.isPointLightShadow!==!0&&this.type===oi&&S(F,T),F.needsUpdate=!1}p=this.type,m.needsUpdate=!1,n.setRenderTarget(v,y,w)};function S(A,_){let T=t.update(M);u.defines.VSM_SAMPLES!==A.blurSamples&&(u.defines.VSM_SAMPLES=A.blurSamples,f.defines.VSM_SAMPLES=A.blurSamples,u.needsUpdate=!0,f.needsUpdate=!0),A.mapPass===null&&(A.mapPass=new ni(s.x,s.y)),u.uniforms.shadow_pass.value=A.map.texture,u.uniforms.resolution.value=A.mapSize,u.uniforms.radius.value=A.radius,n.setRenderTarget(A.mapPass),n.clear(),n.renderBufferDirect(_,null,T,u,M,null),f.uniforms.shadow_pass.value=A.mapPass.texture,f.uniforms.resolution.value=A.mapSize,f.uniforms.radius.value=A.radius,n.setRenderTarget(A.map),n.clear(),n.renderBufferDirect(_,null,T,f,M,null)}function E(A,_,T,v){let y=null,w=T.isPointLight===!0?A.customDistanceMaterial:A.customDepthMaterial;if(w!==void 0)y=w;else if(y=T.isPointLight===!0?l:o,n.localClippingEnabled&&_.clipShadows===!0&&Array.isArray(_.clippingPlanes)&&_.clippingPlanes.length!==0||_.displacementMap&&_.displacementScale!==0||_.alphaMap&&_.alphaTest>0||_.map&&_.alphaTest>0){let P=y.uuid,D=_.uuid,N=c[P];N===void 0&&(N={},c[P]=N);let H=N[D];H===void 0&&(H=y.clone(),N[D]=H,_.addEventListener("dispose",C)),y=H}if(y.visible=_.visible,y.wireframe=_.wireframe,v===oi?y.side=_.shadowSide!==null?_.shadowSide:_.side:y.side=_.shadowSide!==null?_.shadowSide:d[_.side],y.alphaMap=_.alphaMap,y.alphaTest=_.alphaTest,y.map=_.map,y.clipShadows=_.clipShadows,y.clippingPlanes=_.clippingPlanes,y.clipIntersection=_.clipIntersection,y.displacementMap=_.displacementMap,y.displacementScale=_.displacementScale,y.displacementBias=_.displacementBias,y.wireframeLinewidth=_.wireframeLinewidth,y.linewidth=_.linewidth,T.isPointLight===!0&&y.isMeshDistanceMaterial===!0){let P=n.properties.get(y);P.light=T}return y}function g(A,_,T,v,y){if(A.visible===!1)return;if(A.layers.test(_.layers)&&(A.isMesh||A.isLine||A.isPoints)&&(A.castShadow||A.receiveShadow&&y===oi)&&(!A.frustumCulled||i.intersectsObject(A))){A.modelViewMatrix.multiplyMatrices(T.matrixWorldInverse,A.matrixWorld);let D=t.update(A),N=A.material;if(Array.isArray(N)){let H=D.groups;for(let U=0,k=H.length;U<k;U++){let F=H[U],G=N[F.materialIndex];if(G&&G.visible){let q=E(A,G,v,y);A.onBeforeShadow(n,A,_,T,D,q,F),n.renderBufferDirect(T,null,D,q,A,F),A.onAfterShadow(n,A,_,T,D,q,F)}}}else if(N.visible){let H=E(A,N,v,y);A.onBeforeShadow(n,A,_,T,D,H,null),n.renderBufferDirect(T,null,D,H,A,null),A.onAfterShadow(n,A,_,T,D,H,null)}}let P=A.children;for(let D=0,N=P.length;D<N;D++)g(P[D],_,T,v,y)}function C(A){A.target.removeEventListener("dispose",C);for(let T in c){let v=c[T],y=A.target.uuid;y in v&&(v[y].dispose(),delete v[y])}}}var Xy={[Qa]:ja,[tl]:il,[el]:sl,[Ts]:nl,[ja]:Qa,[il]:tl,[sl]:el,[nl]:Ts};function qy(n,t){function e(){let V=!1,Mt=new Le,tt=null,ot=new Le(0,0,0,0);return{setMask:function(Tt){tt!==Tt&&!V&&(n.colorMask(Tt,Tt,Tt,Tt),tt=Tt)},setLocked:function(Tt){V=Tt},setClear:function(Tt,St,jt,Ne,nn){nn===!0&&(Tt*=Ne,St*=Ne,jt*=Ne),Mt.set(Tt,St,jt,Ne),ot.equals(Mt)===!1&&(n.clearColor(Tt,St,jt,Ne),ot.copy(Mt))},reset:function(){V=!1,tt=null,ot.set(-1,0,0,0)}}}function i(){let V=!1,Mt=!1,tt=null,ot=null,Tt=null;return{setReversed:function(St){if(Mt!==St){let jt=t.get("EXT_clip_control");Mt?jt.clipControlEXT(jt.LOWER_LEFT_EXT,jt.ZERO_TO_ONE_EXT):jt.clipControlEXT(jt.LOWER_LEFT_EXT,jt.NEGATIVE_ONE_TO_ONE_EXT);let Ne=Tt;Tt=null,this.setClear(Ne)}Mt=St},getReversed:function(){return Mt},setTest:function(St){St?z(n.DEPTH_TEST):j(n.DEPTH_TEST)},setMask:function(St){tt!==St&&!V&&(n.depthMask(St),tt=St)},setFunc:function(St){if(Mt&&(St=Xy[St]),ot!==St){switch(St){case Qa:n.depthFunc(n.NEVER);break;case ja:n.depthFunc(n.ALWAYS);break;case tl:n.depthFunc(n.LESS);break;case Ts:n.depthFunc(n.LEQUAL);break;case el:n.depthFunc(n.EQUAL);break;case nl:n.depthFunc(n.GEQUAL);break;case il:n.depthFunc(n.GREATER);break;case sl:n.depthFunc(n.NOTEQUAL);break;default:n.depthFunc(n.LEQUAL)}ot=St}},setLocked:function(St){V=St},setClear:function(St){Tt!==St&&(Mt&&(St=1-St),n.clearDepth(St),Tt=St)},reset:function(){V=!1,tt=null,ot=null,Tt=null,Mt=!1}}}function s(){let V=!1,Mt=null,tt=null,ot=null,Tt=null,St=null,jt=null,Ne=null,nn=null;return{setTest:function(ve){V||(ve?z(n.STENCIL_TEST):j(n.STENCIL_TEST))},setMask:function(ve){Mt!==ve&&!V&&(n.stencilMask(ve),Mt=ve)},setFunc:function(ve,kn,mi){(tt!==ve||ot!==kn||Tt!==mi)&&(n.stencilFunc(ve,kn,mi),tt=ve,ot=kn,Tt=mi)},setOp:function(ve,kn,mi){(St!==ve||jt!==kn||Ne!==mi)&&(n.stencilOp(ve,kn,mi),St=ve,jt=kn,Ne=mi)},setLocked:function(ve){V=ve},setClear:function(ve){nn!==ve&&(n.clearStencil(ve),nn=ve)},reset:function(){V=!1,Mt=null,tt=null,ot=null,Tt=null,St=null,jt=null,Ne=null,nn=null}}}let r=new e,a=new i,o=new s,l=new WeakMap,c=new WeakMap,h={},d={},u=new WeakMap,f=[],x=null,M=!1,m=null,p=null,S=null,E=null,g=null,C=null,A=null,_=new Ot(0,0,0),T=0,v=!1,y=null,w=null,P=null,D=null,N=null,H=n.getParameter(n.MAX_COMBINED_TEXTURE_IMAGE_UNITS),U=!1,k=0,F=n.getParameter(n.VERSION);F.indexOf("WebGL")!==-1?(k=parseFloat(/^WebGL (\d)/.exec(F)[1]),U=k>=1):F.indexOf("OpenGL ES")!==-1&&(k=parseFloat(/^OpenGL ES (\d)/.exec(F)[1]),U=k>=2);let G=null,q={},et=n.getParameter(n.SCISSOR_BOX),nt=n.getParameter(n.VIEWPORT),rt=new Le().fromArray(et),B=new Le().fromArray(nt);function Z(V,Mt,tt,ot){let Tt=new Uint8Array(4),St=n.createTexture();n.bindTexture(V,St),n.texParameteri(V,n.TEXTURE_MIN_FILTER,n.NEAREST),n.texParameteri(V,n.TEXTURE_MAG_FILTER,n.NEAREST);for(let jt=0;jt<tt;jt++)V===n.TEXTURE_3D||V===n.TEXTURE_2D_ARRAY?n.texImage3D(Mt,0,n.RGBA,1,1,ot,0,n.RGBA,n.UNSIGNED_BYTE,Tt):n.texImage2D(Mt+jt,0,n.RGBA,1,1,0,n.RGBA,n.UNSIGNED_BYTE,Tt);return St}let ct={};ct[n.TEXTURE_2D]=Z(n.TEXTURE_2D,n.TEXTURE_2D,1),ct[n.TEXTURE_CUBE_MAP]=Z(n.TEXTURE_CUBE_MAP,n.TEXTURE_CUBE_MAP_POSITIVE_X,6),ct[n.TEXTURE_2D_ARRAY]=Z(n.TEXTURE_2D_ARRAY,n.TEXTURE_2D_ARRAY,1,1),ct[n.TEXTURE_3D]=Z(n.TEXTURE_3D,n.TEXTURE_3D,1,1),r.setClear(0,0,0,1),a.setClear(1),o.setClear(0),z(n.DEPTH_TEST),a.setFunc(Ts),pt(!1),At(Qc),z(n.CULL_FACE),L(Ri);function z(V){h[V]!==!0&&(n.enable(V),h[V]=!0)}function j(V){h[V]!==!1&&(n.disable(V),h[V]=!1)}function ft(V,Mt){return d[V]!==Mt?(n.bindFramebuffer(V,Mt),d[V]=Mt,V===n.DRAW_FRAMEBUFFER&&(d[n.FRAMEBUFFER]=Mt),V===n.FRAMEBUFFER&&(d[n.DRAW_FRAMEBUFFER]=Mt),!0):!1}function dt(V,Mt){let tt=f,ot=!1;if(V){tt=u.get(Mt),tt===void 0&&(tt=[],u.set(Mt,tt));let Tt=V.textures;if(tt.length!==Tt.length||tt[0]!==n.COLOR_ATTACHMENT0){for(let St=0,jt=Tt.length;St<jt;St++)tt[St]=n.COLOR_ATTACHMENT0+St;tt.length=Tt.length,ot=!0}}else tt[0]!==n.BACK&&(tt[0]=n.BACK,ot=!0);ot&&n.drawBuffers(tt)}function Ct(V){return x!==V?(n.useProgram(V),x=V,!0):!1}let Q={[Ki]:n.FUNC_ADD,[ju]:n.FUNC_SUBTRACT,[td]:n.FUNC_REVERSE_SUBTRACT};Q[ed]=n.MIN,Q[nd]=n.MAX;let ht={[id]:n.ZERO,[sd]:n.ONE,[rd]:n.SRC_COLOR,[Sa]:n.SRC_ALPHA,[ud]:n.SRC_ALPHA_SATURATE,[cd]:n.DST_COLOR,[ad]:n.DST_ALPHA,[od]:n.ONE_MINUS_SRC_COLOR,[wa]:n.ONE_MINUS_SRC_ALPHA,[hd]:n.ONE_MINUS_DST_COLOR,[ld]:n.ONE_MINUS_DST_ALPHA,[dd]:n.CONSTANT_COLOR,[fd]:n.ONE_MINUS_CONSTANT_COLOR,[pd]:n.CONSTANT_ALPHA,[md]:n.ONE_MINUS_CONSTANT_ALPHA};function L(V,Mt,tt,ot,Tt,St,jt,Ne,nn,ve){if(V===Ri){M===!0&&(j(n.BLEND),M=!1);return}if(M===!1&&(z(n.BLEND),M=!0),V!==Qu){if(V!==m||ve!==v){if((p!==Ki||g!==Ki)&&(n.blendEquation(n.FUNC_ADD),p=Ki,g=Ki),ve)switch(V){case ws:n.blendFuncSeparate(n.ONE,n.ONE_MINUS_SRC_ALPHA,n.ONE,n.ONE_MINUS_SRC_ALPHA);break;case Eo:n.blendFunc(n.ONE,n.ONE);break;case th:n.blendFuncSeparate(n.ZERO,n.ONE_MINUS_SRC_COLOR,n.ZERO,n.ONE);break;case eh:n.blendFuncSeparate(n.ZERO,n.SRC_COLOR,n.ZERO,n.SRC_ALPHA);break;default:console.error("THREE.WebGLState: Invalid blending: ",V);break}else switch(V){case ws:n.blendFuncSeparate(n.SRC_ALPHA,n.ONE_MINUS_SRC_ALPHA,n.ONE,n.ONE_MINUS_SRC_ALPHA);break;case Eo:n.blendFunc(n.SRC_ALPHA,n.ONE);break;case th:n.blendFuncSeparate(n.ZERO,n.ONE_MINUS_SRC_COLOR,n.ZERO,n.ONE);break;case eh:n.blendFunc(n.ZERO,n.SRC_COLOR);break;default:console.error("THREE.WebGLState: Invalid blending: ",V);break}S=null,E=null,C=null,A=null,_.set(0,0,0),T=0,m=V,v=ve}return}Tt=Tt||Mt,St=St||tt,jt=jt||ot,(Mt!==p||Tt!==g)&&(n.blendEquationSeparate(Q[Mt],Q[Tt]),p=Mt,g=Tt),(tt!==S||ot!==E||St!==C||jt!==A)&&(n.blendFuncSeparate(ht[tt],ht[ot],ht[St],ht[jt]),S=tt,E=ot,C=St,A=jt),(Ne.equals(_)===!1||nn!==T)&&(n.blendColor(Ne.r,Ne.g,Ne.b,nn),_.copy(Ne),T=nn),m=V,v=!1}function Nt(V,Mt){V.side===Ce?j(n.CULL_FACE):z(n.CULL_FACE);let tt=V.side===je;Mt&&(tt=!tt),pt(tt),V.blending===ws&&V.transparent===!1?L(Ri):L(V.blending,V.blendEquation,V.blendSrc,V.blendDst,V.blendEquationAlpha,V.blendSrcAlpha,V.blendDstAlpha,V.blendColor,V.blendAlpha,V.premultipliedAlpha),a.setFunc(V.depthFunc),a.setTest(V.depthTest),a.setMask(V.depthWrite),r.setMask(V.colorWrite);let ot=V.stencilWrite;o.setTest(ot),ot&&(o.setMask(V.stencilWriteMask),o.setFunc(V.stencilFunc,V.stencilRef,V.stencilFuncMask),o.setOp(V.stencilFail,V.stencilZFail,V.stencilZPass)),Wt(V.polygonOffset,V.polygonOffsetFactor,V.polygonOffsetUnits),V.alphaToCoverage===!0?z(n.SAMPLE_ALPHA_TO_COVERAGE):j(n.SAMPLE_ALPHA_TO_COVERAGE)}function pt(V){y!==V&&(V?n.frontFace(n.CW):n.frontFace(n.CCW),y=V)}function At(V){V!==Ju?(z(n.CULL_FACE),V!==w&&(V===Qc?n.cullFace(n.BACK):V===Ku?n.cullFace(n.FRONT):n.cullFace(n.FRONT_AND_BACK))):j(n.CULL_FACE),w=V}function xt(V){V!==P&&(U&&n.lineWidth(V),P=V)}function Wt(V,Mt,tt){V?(z(n.POLYGON_OFFSET_FILL),(D!==Mt||N!==tt)&&(n.polygonOffset(Mt,tt),D=Mt,N=tt)):j(n.POLYGON_OFFSET_FILL)}function wt(V){V?z(n.SCISSOR_TEST):j(n.SCISSOR_TEST)}function I(V){V===void 0&&(V=n.TEXTURE0+H-1),G!==V&&(n.activeTexture(V),G=V)}function b(V,Mt,tt){tt===void 0&&(G===null?tt=n.TEXTURE0+H-1:tt=G);let ot=q[tt];ot===void 0&&(ot={type:void 0,texture:void 0},q[tt]=ot),(ot.type!==V||ot.texture!==Mt)&&(G!==tt&&(n.activeTexture(tt),G=tt),n.bindTexture(V,Mt||ct[V]),ot.type=V,ot.texture=Mt)}function Y(){let V=q[G];V!==void 0&&V.type!==void 0&&(n.bindTexture(V.type,null),V.type=void 0,V.texture=void 0)}function it(){try{n.compressedTexImage2D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function ut(){try{n.compressedTexImage3D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function st(){try{n.texSubImage2D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function Ut(){try{n.texSubImage3D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function vt(){try{n.compressedTexSubImage2D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function bt(){try{n.compressedTexSubImage3D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function ce(){try{n.texStorage2D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function gt(){try{n.texStorage3D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function Pt(){try{n.texImage2D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function Gt(){try{n.texImage3D.apply(n,arguments)}catch(V){console.error("THREE.WebGLState:",V)}}function Yt(V){rt.equals(V)===!1&&(n.scissor(V.x,V.y,V.z,V.w),rt.copy(V))}function It(V){B.equals(V)===!1&&(n.viewport(V.x,V.y,V.z,V.w),B.copy(V))}function ue(V,Mt){let tt=c.get(Mt);tt===void 0&&(tt=new WeakMap,c.set(Mt,tt));let ot=tt.get(V);ot===void 0&&(ot=n.getUniformBlockIndex(Mt,V.name),tt.set(V,ot))}function ee(V,Mt){let ot=c.get(Mt).get(V);l.get(Mt)!==ot&&(n.uniformBlockBinding(Mt,ot,V.__bindingPointIndex),l.set(Mt,ot))}function Te(){n.disable(n.BLEND),n.disable(n.CULL_FACE),n.disable(n.DEPTH_TEST),n.disable(n.POLYGON_OFFSET_FILL),n.disable(n.SCISSOR_TEST),n.disable(n.STENCIL_TEST),n.disable(n.SAMPLE_ALPHA_TO_COVERAGE),n.blendEquation(n.FUNC_ADD),n.blendFunc(n.ONE,n.ZERO),n.blendFuncSeparate(n.ONE,n.ZERO,n.ONE,n.ZERO),n.blendColor(0,0,0,0),n.colorMask(!0,!0,!0,!0),n.clearColor(0,0,0,0),n.depthMask(!0),n.depthFunc(n.LESS),a.setReversed(!1),n.clearDepth(1),n.stencilMask(4294967295),n.stencilFunc(n.ALWAYS,0,4294967295),n.stencilOp(n.KEEP,n.KEEP,n.KEEP),n.clearStencil(0),n.cullFace(n.BACK),n.frontFace(n.CCW),n.polygonOffset(0,0),n.activeTexture(n.TEXTURE0),n.bindFramebuffer(n.FRAMEBUFFER,null),n.bindFramebuffer(n.DRAW_FRAMEBUFFER,null),n.bindFramebuffer(n.READ_FRAMEBUFFER,null),n.useProgram(null),n.lineWidth(1),n.scissor(0,0,n.canvas.width,n.canvas.height),n.viewport(0,0,n.canvas.width,n.canvas.height),h={},G=null,q={},d={},u=new WeakMap,f=[],x=null,M=!1,m=null,p=null,S=null,E=null,g=null,C=null,A=null,_=new Ot(0,0,0),T=0,v=!1,y=null,w=null,P=null,D=null,N=null,rt.set(0,0,n.canvas.width,n.canvas.height),B.set(0,0,n.canvas.width,n.canvas.height),r.reset(),a.reset(),o.reset()}return{buffers:{color:r,depth:a,stencil:o},enable:z,disable:j,bindFramebuffer:ft,drawBuffers:dt,useProgram:Ct,setBlending:L,setMaterial:Nt,setFlipSided:pt,setCullFace:At,setLineWidth:xt,setPolygonOffset:Wt,setScissorTest:wt,activeTexture:I,bindTexture:b,unbindTexture:Y,compressedTexImage2D:it,compressedTexImage3D:ut,texImage2D:Pt,texImage3D:Gt,updateUBOMapping:ue,uniformBlockBinding:ee,texStorage2D:ce,texStorage3D:gt,texSubImage2D:st,texSubImage3D:Ut,compressedTexSubImage2D:vt,compressedTexSubImage3D:bt,scissor:Yt,viewport:It,reset:Te}}function Yy(n,t,e,i,s,r,a){let o=t.has("WEBGL_multisampled_render_to_texture")?t.get("WEBGL_multisampled_render_to_texture"):null,l=typeof navigator=="undefined"?!1:/OculusBrowser/g.test(navigator.userAgent),c=new at,h=new WeakMap,d,u=new WeakMap,f=!1;try{f=typeof OffscreenCanvas!="undefined"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function x(I,b){return f?new OffscreenCanvas(I,b):ur("canvas")}function M(I,b,Y){let it=1,ut=wt(I);if((ut.width>Y||ut.height>Y)&&(it=Y/Math.max(ut.width,ut.height)),it<1)if(typeof HTMLImageElement!="undefined"&&I instanceof HTMLImageElement||typeof HTMLCanvasElement!="undefined"&&I instanceof HTMLCanvasElement||typeof ImageBitmap!="undefined"&&I instanceof ImageBitmap||typeof VideoFrame!="undefined"&&I instanceof VideoFrame){let st=Math.floor(it*ut.width),Ut=Math.floor(it*ut.height);d===void 0&&(d=x(st,Ut));let vt=b?x(st,Ut):d;return vt.width=st,vt.height=Ut,vt.getContext("2d").drawImage(I,0,0,st,Ut),console.warn("THREE.WebGLRenderer: Texture has been resized from ("+ut.width+"x"+ut.height+") to ("+st+"x"+Ut+")."),vt}else return"data"in I&&console.warn("THREE.WebGLRenderer: Image in DataTexture is too big ("+ut.width+"x"+ut.height+")."),I;return I}function m(I){return I.generateMipmaps}function p(I){n.generateMipmap(I)}function S(I){return I.isWebGLCubeRenderTarget?n.TEXTURE_CUBE_MAP:I.isWebGL3DRenderTarget?n.TEXTURE_3D:I.isWebGLArrayRenderTarget||I.isCompressedArrayTexture?n.TEXTURE_2D_ARRAY:n.TEXTURE_2D}function E(I,b,Y,it,ut=!1){if(I!==null){if(n[I]!==void 0)return n[I];console.warn("THREE.WebGLRenderer: Attempt to use non-existing WebGL internal format '"+I+"'")}let st=b;if(b===n.RED&&(Y===n.FLOAT&&(st=n.R32F),Y===n.HALF_FLOAT&&(st=n.R16F),Y===n.UNSIGNED_BYTE&&(st=n.R8)),b===n.RED_INTEGER&&(Y===n.UNSIGNED_BYTE&&(st=n.R8UI),Y===n.UNSIGNED_SHORT&&(st=n.R16UI),Y===n.UNSIGNED_INT&&(st=n.R32UI),Y===n.BYTE&&(st=n.R8I),Y===n.SHORT&&(st=n.R16I),Y===n.INT&&(st=n.R32I)),b===n.RG&&(Y===n.FLOAT&&(st=n.RG32F),Y===n.HALF_FLOAT&&(st=n.RG16F),Y===n.UNSIGNED_BYTE&&(st=n.RG8)),b===n.RG_INTEGER&&(Y===n.UNSIGNED_BYTE&&(st=n.RG8UI),Y===n.UNSIGNED_SHORT&&(st=n.RG16UI),Y===n.UNSIGNED_INT&&(st=n.RG32UI),Y===n.BYTE&&(st=n.RG8I),Y===n.SHORT&&(st=n.RG16I),Y===n.INT&&(st=n.RG32I)),b===n.RGB_INTEGER&&(Y===n.UNSIGNED_BYTE&&(st=n.RGB8UI),Y===n.UNSIGNED_SHORT&&(st=n.RGB16UI),Y===n.UNSIGNED_INT&&(st=n.RGB32UI),Y===n.BYTE&&(st=n.RGB8I),Y===n.SHORT&&(st=n.RGB16I),Y===n.INT&&(st=n.RGB32I)),b===n.RGBA_INTEGER&&(Y===n.UNSIGNED_BYTE&&(st=n.RGBA8UI),Y===n.UNSIGNED_SHORT&&(st=n.RGBA16UI),Y===n.UNSIGNED_INT&&(st=n.RGBA32UI),Y===n.BYTE&&(st=n.RGBA8I),Y===n.SHORT&&(st=n.RGBA16I),Y===n.INT&&(st=n.RGBA32I)),b===n.RGB&&Y===n.UNSIGNED_INT_5_9_9_9_REV&&(st=n.RGB9_E5),b===n.RGBA){let Ut=ut?Yr:pe.getTransfer(it);Y===n.FLOAT&&(st=n.RGBA32F),Y===n.HALF_FLOAT&&(st=n.RGBA16F),Y===n.UNSIGNED_BYTE&&(st=Ut===Me?n.SRGB8_ALPHA8:n.RGBA8),Y===n.UNSIGNED_SHORT_4_4_4_4&&(st=n.RGBA4),Y===n.UNSIGNED_SHORT_5_5_5_1&&(st=n.RGB5_A1)}return(st===n.R16F||st===n.R32F||st===n.RG16F||st===n.RG32F||st===n.RGBA16F||st===n.RGBA32F)&&t.get("EXT_color_buffer_float"),st}function g(I,b){let Y;return I?b===null||b===ss||b===Us?Y=n.DEPTH24_STENCIL8:b===Yn?Y=n.DEPTH32F_STENCIL8:b===_r&&(Y=n.DEPTH24_STENCIL8,console.warn("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):b===null||b===ss||b===Us?Y=n.DEPTH_COMPONENT24:b===Yn?Y=n.DEPTH_COMPONENT32F:b===_r&&(Y=n.DEPTH_COMPONENT16),Y}function C(I,b){return m(I)===!0||I.isFramebufferTexture&&I.minFilter!==xn&&I.minFilter!==Xn?Math.log2(Math.max(b.width,b.height))+1:I.mipmaps!==void 0&&I.mipmaps.length>0?I.mipmaps.length:I.isCompressedTexture&&Array.isArray(I.image)?b.mipmaps.length:1}function A(I){let b=I.target;b.removeEventListener("dispose",A),T(b),b.isVideoTexture&&h.delete(b)}function _(I){let b=I.target;b.removeEventListener("dispose",_),y(b)}function T(I){let b=i.get(I);if(b.__webglInit===void 0)return;let Y=I.source,it=u.get(Y);if(it){let ut=it[b.__cacheKey];ut.usedTimes--,ut.usedTimes===0&&v(I),Object.keys(it).length===0&&u.delete(Y)}i.remove(I)}function v(I){let b=i.get(I);n.deleteTexture(b.__webglTexture);let Y=I.source,it=u.get(Y);delete it[b.__cacheKey],a.memory.textures--}function y(I){let b=i.get(I);if(I.depthTexture&&(I.depthTexture.dispose(),i.remove(I.depthTexture)),I.isWebGLCubeRenderTarget)for(let it=0;it<6;it++){if(Array.isArray(b.__webglFramebuffer[it]))for(let ut=0;ut<b.__webglFramebuffer[it].length;ut++)n.deleteFramebuffer(b.__webglFramebuffer[it][ut]);else n.deleteFramebuffer(b.__webglFramebuffer[it]);b.__webglDepthbuffer&&n.deleteRenderbuffer(b.__webglDepthbuffer[it])}else{if(Array.isArray(b.__webglFramebuffer))for(let it=0;it<b.__webglFramebuffer.length;it++)n.deleteFramebuffer(b.__webglFramebuffer[it]);else n.deleteFramebuffer(b.__webglFramebuffer);if(b.__webglDepthbuffer&&n.deleteRenderbuffer(b.__webglDepthbuffer),b.__webglMultisampledFramebuffer&&n.deleteFramebuffer(b.__webglMultisampledFramebuffer),b.__webglColorRenderbuffer)for(let it=0;it<b.__webglColorRenderbuffer.length;it++)b.__webglColorRenderbuffer[it]&&n.deleteRenderbuffer(b.__webglColorRenderbuffer[it]);b.__webglDepthRenderbuffer&&n.deleteRenderbuffer(b.__webglDepthRenderbuffer)}let Y=I.textures;for(let it=0,ut=Y.length;it<ut;it++){let st=i.get(Y[it]);st.__webglTexture&&(n.deleteTexture(st.__webglTexture),a.memory.textures--),i.remove(Y[it])}i.remove(I)}let w=0;function P(){w=0}function D(){let I=w;return I>=s.maxTextures&&console.warn("THREE.WebGLTextures: Trying to use "+I+" texture units while this GPU supports only "+s.maxTextures),w+=1,I}function N(I){let b=[];return b.push(I.wrapS),b.push(I.wrapT),b.push(I.wrapR||0),b.push(I.magFilter),b.push(I.minFilter),b.push(I.anisotropy),b.push(I.internalFormat),b.push(I.format),b.push(I.type),b.push(I.generateMipmaps),b.push(I.premultiplyAlpha),b.push(I.flipY),b.push(I.unpackAlignment),b.push(I.colorSpace),b.join()}function H(I,b){let Y=i.get(I);if(I.isVideoTexture&&xt(I),I.isRenderTargetTexture===!1&&I.version>0&&Y.__version!==I.version){let it=I.image;if(it===null)console.warn("THREE.WebGLRenderer: Texture marked for update but no image data found.");else if(it.complete===!1)console.warn("THREE.WebGLRenderer: Texture marked for update but image is incomplete");else{B(Y,I,b);return}}e.bindTexture(n.TEXTURE_2D,Y.__webglTexture,n.TEXTURE0+b)}function U(I,b){let Y=i.get(I);if(I.version>0&&Y.__version!==I.version){B(Y,I,b);return}e.bindTexture(n.TEXTURE_2D_ARRAY,Y.__webglTexture,n.TEXTURE0+b)}function k(I,b){let Y=i.get(I);if(I.version>0&&Y.__version!==I.version){B(Y,I,b);return}e.bindTexture(n.TEXTURE_3D,Y.__webglTexture,n.TEXTURE0+b)}function F(I,b){let Y=i.get(I);if(I.version>0&&Y.__version!==I.version){Z(Y,I,b);return}e.bindTexture(n.TEXTURE_CUBE_MAP,Y.__webglTexture,n.TEXTURE0+b)}let G={[Ge]:n.REPEAT,[Ji]:n.CLAMP_TO_EDGE,[hr]:n.MIRRORED_REPEAT},q={[xn]:n.NEAREST,[wd]:n.NEAREST_MIPMAP_NEAREST,[wo]:n.NEAREST_MIPMAP_LINEAR,[Xn]:n.LINEAR,[cl]:n.LINEAR_MIPMAP_NEAREST,[is]:n.LINEAR_MIPMAP_LINEAR},et={[Rd]:n.NEVER,[Ud]:n.ALWAYS,[Cd]:n.LESS,[dh]:n.LEQUAL,[Pd]:n.EQUAL,[Dd]:n.GEQUAL,[Id]:n.GREATER,[Ld]:n.NOTEQUAL};function nt(I,b){if(b.type===Yn&&t.has("OES_texture_float_linear")===!1&&(b.magFilter===Xn||b.magFilter===cl||b.magFilter===wo||b.magFilter===is||b.minFilter===Xn||b.minFilter===cl||b.minFilter===wo||b.minFilter===is)&&console.warn("THREE.WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),n.texParameteri(I,n.TEXTURE_WRAP_S,G[b.wrapS]),n.texParameteri(I,n.TEXTURE_WRAP_T,G[b.wrapT]),(I===n.TEXTURE_3D||I===n.TEXTURE_2D_ARRAY)&&n.texParameteri(I,n.TEXTURE_WRAP_R,G[b.wrapR]),n.texParameteri(I,n.TEXTURE_MAG_FILTER,q[b.magFilter]),n.texParameteri(I,n.TEXTURE_MIN_FILTER,q[b.minFilter]),b.compareFunction&&(n.texParameteri(I,n.TEXTURE_COMPARE_MODE,n.COMPARE_REF_TO_TEXTURE),n.texParameteri(I,n.TEXTURE_COMPARE_FUNC,et[b.compareFunction])),t.has("EXT_texture_filter_anisotropic")===!0){if(b.magFilter===xn||b.minFilter!==wo&&b.minFilter!==is||b.type===Yn&&t.has("OES_texture_float_linear")===!1)return;if(b.anisotropy>1||i.get(b).__currentAnisotropy){let Y=t.get("EXT_texture_filter_anisotropic");n.texParameterf(I,Y.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(b.anisotropy,s.getMaxAnisotropy())),i.get(b).__currentAnisotropy=b.anisotropy}}}function rt(I,b){let Y=!1;I.__webglInit===void 0&&(I.__webglInit=!0,b.addEventListener("dispose",A));let it=b.source,ut=u.get(it);ut===void 0&&(ut={},u.set(it,ut));let st=N(b);if(st!==I.__cacheKey){ut[st]===void 0&&(ut[st]={texture:n.createTexture(),usedTimes:0},a.memory.textures++,Y=!0),ut[st].usedTimes++;let Ut=ut[I.__cacheKey];Ut!==void 0&&(ut[I.__cacheKey].usedTimes--,Ut.usedTimes===0&&v(b)),I.__cacheKey=st,I.__webglTexture=ut[st].texture}return Y}function B(I,b,Y){let it=n.TEXTURE_2D;(b.isDataArrayTexture||b.isCompressedArrayTexture)&&(it=n.TEXTURE_2D_ARRAY),b.isData3DTexture&&(it=n.TEXTURE_3D);let ut=rt(I,b),st=b.source;e.bindTexture(it,I.__webglTexture,n.TEXTURE0+Y);let Ut=i.get(st);if(st.version!==Ut.__version||ut===!0){e.activeTexture(n.TEXTURE0+Y);let vt=pe.getPrimaries(pe.workingColorSpace),bt=b.colorSpace===Pi?null:pe.getPrimaries(b.colorSpace),ce=b.colorSpace===Pi||vt===bt?n.NONE:n.BROWSER_DEFAULT_WEBGL;n.pixelStorei(n.UNPACK_FLIP_Y_WEBGL,b.flipY),n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,b.premultiplyAlpha),n.pixelStorei(n.UNPACK_ALIGNMENT,b.unpackAlignment),n.pixelStorei(n.UNPACK_COLORSPACE_CONVERSION_WEBGL,ce);let gt=M(b.image,!1,s.maxTextureSize);gt=Wt(b,gt);let Pt=r.convert(b.format,b.colorSpace),Gt=r.convert(b.type),Yt=E(b.internalFormat,Pt,Gt,b.colorSpace,b.isVideoTexture);nt(it,b);let It,ue=b.mipmaps,ee=b.isVideoTexture!==!0,Te=Ut.__version===void 0||ut===!0,V=st.dataReady,Mt=C(b,gt);if(b.isDepthTexture)Yt=g(b.format===bs,b.type),Te&&(ee?e.texStorage2D(n.TEXTURE_2D,1,Yt,gt.width,gt.height):e.texImage2D(n.TEXTURE_2D,0,Yt,gt.width,gt.height,0,Pt,Gt,null));else if(b.isDataTexture)if(ue.length>0){ee&&Te&&e.texStorage2D(n.TEXTURE_2D,Mt,Yt,ue[0].width,ue[0].height);for(let tt=0,ot=ue.length;tt<ot;tt++)It=ue[tt],ee?V&&e.texSubImage2D(n.TEXTURE_2D,tt,0,0,It.width,It.height,Pt,Gt,It.data):e.texImage2D(n.TEXTURE_2D,tt,Yt,It.width,It.height,0,Pt,Gt,It.data);b.generateMipmaps=!1}else ee?(Te&&e.texStorage2D(n.TEXTURE_2D,Mt,Yt,gt.width,gt.height),V&&e.texSubImage2D(n.TEXTURE_2D,0,0,0,gt.width,gt.height,Pt,Gt,gt.data)):e.texImage2D(n.TEXTURE_2D,0,Yt,gt.width,gt.height,0,Pt,Gt,gt.data);else if(b.isCompressedTexture)if(b.isCompressedArrayTexture){ee&&Te&&e.texStorage3D(n.TEXTURE_2D_ARRAY,Mt,Yt,ue[0].width,ue[0].height,gt.depth);for(let tt=0,ot=ue.length;tt<ot;tt++)if(It=ue[tt],b.format!==Un)if(Pt!==null)if(ee){if(V)if(b.layerUpdates.size>0){let Tt=_h(It.width,It.height,b.format,b.type);for(let St of b.layerUpdates){let jt=It.data.subarray(St*Tt/It.data.BYTES_PER_ELEMENT,(St+1)*Tt/It.data.BYTES_PER_ELEMENT);e.compressedTexSubImage3D(n.TEXTURE_2D_ARRAY,tt,0,0,St,It.width,It.height,1,Pt,jt)}b.clearLayerUpdates()}else e.compressedTexSubImage3D(n.TEXTURE_2D_ARRAY,tt,0,0,0,It.width,It.height,gt.depth,Pt,It.data)}else e.compressedTexImage3D(n.TEXTURE_2D_ARRAY,tt,Yt,It.width,It.height,gt.depth,0,It.data,0,0);else console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else ee?V&&e.texSubImage3D(n.TEXTURE_2D_ARRAY,tt,0,0,0,It.width,It.height,gt.depth,Pt,Gt,It.data):e.texImage3D(n.TEXTURE_2D_ARRAY,tt,Yt,It.width,It.height,gt.depth,0,Pt,Gt,It.data)}else{ee&&Te&&e.texStorage2D(n.TEXTURE_2D,Mt,Yt,ue[0].width,ue[0].height);for(let tt=0,ot=ue.length;tt<ot;tt++)It=ue[tt],b.format!==Un?Pt!==null?ee?V&&e.compressedTexSubImage2D(n.TEXTURE_2D,tt,0,0,It.width,It.height,Pt,It.data):e.compressedTexImage2D(n.TEXTURE_2D,tt,Yt,It.width,It.height,0,It.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):ee?V&&e.texSubImage2D(n.TEXTURE_2D,tt,0,0,It.width,It.height,Pt,Gt,It.data):e.texImage2D(n.TEXTURE_2D,tt,Yt,It.width,It.height,0,Pt,Gt,It.data)}else if(b.isDataArrayTexture)if(ee){if(Te&&e.texStorage3D(n.TEXTURE_2D_ARRAY,Mt,Yt,gt.width,gt.height,gt.depth),V)if(b.layerUpdates.size>0){let tt=_h(gt.width,gt.height,b.format,b.type);for(let ot of b.layerUpdates){let Tt=gt.data.subarray(ot*tt/gt.data.BYTES_PER_ELEMENT,(ot+1)*tt/gt.data.BYTES_PER_ELEMENT);e.texSubImage3D(n.TEXTURE_2D_ARRAY,0,0,0,ot,gt.width,gt.height,1,Pt,Gt,Tt)}b.clearLayerUpdates()}else e.texSubImage3D(n.TEXTURE_2D_ARRAY,0,0,0,0,gt.width,gt.height,gt.depth,Pt,Gt,gt.data)}else e.texImage3D(n.TEXTURE_2D_ARRAY,0,Yt,gt.width,gt.height,gt.depth,0,Pt,Gt,gt.data);else if(b.isData3DTexture)ee?(Te&&e.texStorage3D(n.TEXTURE_3D,Mt,Yt,gt.width,gt.height,gt.depth),V&&e.texSubImage3D(n.TEXTURE_3D,0,0,0,0,gt.width,gt.height,gt.depth,Pt,Gt,gt.data)):e.texImage3D(n.TEXTURE_3D,0,Yt,gt.width,gt.height,gt.depth,0,Pt,Gt,gt.data);else if(b.isFramebufferTexture){if(Te)if(ee)e.texStorage2D(n.TEXTURE_2D,Mt,Yt,gt.width,gt.height);else{let tt=gt.width,ot=gt.height;for(let Tt=0;Tt<Mt;Tt++)e.texImage2D(n.TEXTURE_2D,Tt,Yt,tt,ot,0,Pt,Gt,null),tt>>=1,ot>>=1}}else if(ue.length>0){if(ee&&Te){let tt=wt(ue[0]);e.texStorage2D(n.TEXTURE_2D,Mt,Yt,tt.width,tt.height)}for(let tt=0,ot=ue.length;tt<ot;tt++)It=ue[tt],ee?V&&e.texSubImage2D(n.TEXTURE_2D,tt,0,0,Pt,Gt,It):e.texImage2D(n.TEXTURE_2D,tt,Yt,Pt,Gt,It);b.generateMipmaps=!1}else if(ee){if(Te){let tt=wt(gt);e.texStorage2D(n.TEXTURE_2D,Mt,Yt,tt.width,tt.height)}V&&e.texSubImage2D(n.TEXTURE_2D,0,0,0,Pt,Gt,gt)}else e.texImage2D(n.TEXTURE_2D,0,Yt,Pt,Gt,gt);m(b)&&p(it),Ut.__version=st.version,b.onUpdate&&b.onUpdate(b)}I.__version=b.version}function Z(I,b,Y){if(b.image.length!==6)return;let it=rt(I,b),ut=b.source;e.bindTexture(n.TEXTURE_CUBE_MAP,I.__webglTexture,n.TEXTURE0+Y);let st=i.get(ut);if(ut.version!==st.__version||it===!0){e.activeTexture(n.TEXTURE0+Y);let Ut=pe.getPrimaries(pe.workingColorSpace),vt=b.colorSpace===Pi?null:pe.getPrimaries(b.colorSpace),bt=b.colorSpace===Pi||Ut===vt?n.NONE:n.BROWSER_DEFAULT_WEBGL;n.pixelStorei(n.UNPACK_FLIP_Y_WEBGL,b.flipY),n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,b.premultiplyAlpha),n.pixelStorei(n.UNPACK_ALIGNMENT,b.unpackAlignment),n.pixelStorei(n.UNPACK_COLORSPACE_CONVERSION_WEBGL,bt);let ce=b.isCompressedTexture||b.image[0].isCompressedTexture,gt=b.image[0]&&b.image[0].isDataTexture,Pt=[];for(let ot=0;ot<6;ot++)!ce&&!gt?Pt[ot]=M(b.image[ot],!0,s.maxCubemapSize):Pt[ot]=gt?b.image[ot].image:b.image[ot],Pt[ot]=Wt(b,Pt[ot]);let Gt=Pt[0],Yt=r.convert(b.format,b.colorSpace),It=r.convert(b.type),ue=E(b.internalFormat,Yt,It,b.colorSpace),ee=b.isVideoTexture!==!0,Te=st.__version===void 0||it===!0,V=ut.dataReady,Mt=C(b,Gt);nt(n.TEXTURE_CUBE_MAP,b);let tt;if(ce){ee&&Te&&e.texStorage2D(n.TEXTURE_CUBE_MAP,Mt,ue,Gt.width,Gt.height);for(let ot=0;ot<6;ot++){tt=Pt[ot].mipmaps;for(let Tt=0;Tt<tt.length;Tt++){let St=tt[Tt];b.format!==Un?Yt!==null?ee?V&&e.compressedTexSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,Tt,0,0,St.width,St.height,Yt,St.data):e.compressedTexImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,Tt,ue,St.width,St.height,0,St.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):ee?V&&e.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,Tt,0,0,St.width,St.height,Yt,It,St.data):e.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,Tt,ue,St.width,St.height,0,Yt,It,St.data)}}}else{if(tt=b.mipmaps,ee&&Te){tt.length>0&&Mt++;let ot=wt(Pt[0]);e.texStorage2D(n.TEXTURE_CUBE_MAP,Mt,ue,ot.width,ot.height)}for(let ot=0;ot<6;ot++)if(gt){ee?V&&e.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,0,0,0,Pt[ot].width,Pt[ot].height,Yt,It,Pt[ot].data):e.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,0,ue,Pt[ot].width,Pt[ot].height,0,Yt,It,Pt[ot].data);for(let Tt=0;Tt<tt.length;Tt++){let jt=tt[Tt].image[ot].image;ee?V&&e.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,Tt+1,0,0,jt.width,jt.height,Yt,It,jt.data):e.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,Tt+1,ue,jt.width,jt.height,0,Yt,It,jt.data)}}else{ee?V&&e.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,0,0,0,Yt,It,Pt[ot]):e.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,0,ue,Yt,It,Pt[ot]);for(let Tt=0;Tt<tt.length;Tt++){let St=tt[Tt];ee?V&&e.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,Tt+1,0,0,Yt,It,St.image[ot]):e.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+ot,Tt+1,ue,Yt,It,St.image[ot])}}}m(b)&&p(n.TEXTURE_CUBE_MAP),st.__version=ut.version,b.onUpdate&&b.onUpdate(b)}I.__version=b.version}function ct(I,b,Y,it,ut,st){let Ut=r.convert(Y.format,Y.colorSpace),vt=r.convert(Y.type),bt=E(Y.internalFormat,Ut,vt,Y.colorSpace),ce=i.get(b),gt=i.get(Y);if(gt.__renderTarget=b,!ce.__hasExternalTextures){let Pt=Math.max(1,b.width>>st),Gt=Math.max(1,b.height>>st);ut===n.TEXTURE_3D||ut===n.TEXTURE_2D_ARRAY?e.texImage3D(ut,st,bt,Pt,Gt,b.depth,0,Ut,vt,null):e.texImage2D(ut,st,bt,Pt,Gt,0,Ut,vt,null)}e.bindFramebuffer(n.FRAMEBUFFER,I),At(b)?o.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,it,ut,gt.__webglTexture,0,pt(b)):(ut===n.TEXTURE_2D||ut>=n.TEXTURE_CUBE_MAP_POSITIVE_X&&ut<=n.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&n.framebufferTexture2D(n.FRAMEBUFFER,it,ut,gt.__webglTexture,st),e.bindFramebuffer(n.FRAMEBUFFER,null)}function z(I,b,Y){if(n.bindRenderbuffer(n.RENDERBUFFER,I),b.depthBuffer){let it=b.depthTexture,ut=it&&it.isDepthTexture?it.type:null,st=g(b.stencilBuffer,ut),Ut=b.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,vt=pt(b);At(b)?o.renderbufferStorageMultisampleEXT(n.RENDERBUFFER,vt,st,b.width,b.height):Y?n.renderbufferStorageMultisample(n.RENDERBUFFER,vt,st,b.width,b.height):n.renderbufferStorage(n.RENDERBUFFER,st,b.width,b.height),n.framebufferRenderbuffer(n.FRAMEBUFFER,Ut,n.RENDERBUFFER,I)}else{let it=b.textures;for(let ut=0;ut<it.length;ut++){let st=it[ut],Ut=r.convert(st.format,st.colorSpace),vt=r.convert(st.type),bt=E(st.internalFormat,Ut,vt,st.colorSpace),ce=pt(b);Y&&At(b)===!1?n.renderbufferStorageMultisample(n.RENDERBUFFER,ce,bt,b.width,b.height):At(b)?o.renderbufferStorageMultisampleEXT(n.RENDERBUFFER,ce,bt,b.width,b.height):n.renderbufferStorage(n.RENDERBUFFER,bt,b.width,b.height)}}n.bindRenderbuffer(n.RENDERBUFFER,null)}function j(I,b){if(b&&b.isWebGLCubeRenderTarget)throw new Error("Depth Texture with cube render targets is not supported");if(e.bindFramebuffer(n.FRAMEBUFFER,I),!(b.depthTexture&&b.depthTexture.isDepthTexture))throw new Error("renderTarget.depthTexture must be an instance of THREE.DepthTexture");let it=i.get(b.depthTexture);it.__renderTarget=b,(!it.__webglTexture||b.depthTexture.image.width!==b.width||b.depthTexture.image.height!==b.height)&&(b.depthTexture.image.width=b.width,b.depthTexture.image.height=b.height,b.depthTexture.needsUpdate=!0),H(b.depthTexture,0);let ut=it.__webglTexture,st=pt(b);if(b.depthTexture.format===Ss)At(b)?o.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,n.DEPTH_ATTACHMENT,n.TEXTURE_2D,ut,0,st):n.framebufferTexture2D(n.FRAMEBUFFER,n.DEPTH_ATTACHMENT,n.TEXTURE_2D,ut,0);else if(b.depthTexture.format===bs)At(b)?o.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,n.DEPTH_STENCIL_ATTACHMENT,n.TEXTURE_2D,ut,0,st):n.framebufferTexture2D(n.FRAMEBUFFER,n.DEPTH_STENCIL_ATTACHMENT,n.TEXTURE_2D,ut,0);else throw new Error("Unknown depthTexture format")}function ft(I){let b=i.get(I),Y=I.isWebGLCubeRenderTarget===!0;if(b.__boundDepthTexture!==I.depthTexture){let it=I.depthTexture;if(b.__depthDisposeCallback&&b.__depthDisposeCallback(),it){let ut=()=>{delete b.__boundDepthTexture,delete b.__depthDisposeCallback,it.removeEventListener("dispose",ut)};it.addEventListener("dispose",ut),b.__depthDisposeCallback=ut}b.__boundDepthTexture=it}if(I.depthTexture&&!b.__autoAllocateDepthBuffer){if(Y)throw new Error("target.depthTexture not supported in Cube render targets");j(b.__webglFramebuffer,I)}else if(Y){b.__webglDepthbuffer=[];for(let it=0;it<6;it++)if(e.bindFramebuffer(n.FRAMEBUFFER,b.__webglFramebuffer[it]),b.__webglDepthbuffer[it]===void 0)b.__webglDepthbuffer[it]=n.createRenderbuffer(),z(b.__webglDepthbuffer[it],I,!1);else{let ut=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,st=b.__webglDepthbuffer[it];n.bindRenderbuffer(n.RENDERBUFFER,st),n.framebufferRenderbuffer(n.FRAMEBUFFER,ut,n.RENDERBUFFER,st)}}else if(e.bindFramebuffer(n.FRAMEBUFFER,b.__webglFramebuffer),b.__webglDepthbuffer===void 0)b.__webglDepthbuffer=n.createRenderbuffer(),z(b.__webglDepthbuffer,I,!1);else{let it=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,ut=b.__webglDepthbuffer;n.bindRenderbuffer(n.RENDERBUFFER,ut),n.framebufferRenderbuffer(n.FRAMEBUFFER,it,n.RENDERBUFFER,ut)}e.bindFramebuffer(n.FRAMEBUFFER,null)}function dt(I,b,Y){let it=i.get(I);b!==void 0&&ct(it.__webglFramebuffer,I,I.texture,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,0),Y!==void 0&&ft(I)}function Ct(I){let b=I.texture,Y=i.get(I),it=i.get(b);I.addEventListener("dispose",_);let ut=I.textures,st=I.isWebGLCubeRenderTarget===!0,Ut=ut.length>1;if(Ut||(it.__webglTexture===void 0&&(it.__webglTexture=n.createTexture()),it.__version=b.version,a.memory.textures++),st){Y.__webglFramebuffer=[];for(let vt=0;vt<6;vt++)if(b.mipmaps&&b.mipmaps.length>0){Y.__webglFramebuffer[vt]=[];for(let bt=0;bt<b.mipmaps.length;bt++)Y.__webglFramebuffer[vt][bt]=n.createFramebuffer()}else Y.__webglFramebuffer[vt]=n.createFramebuffer()}else{if(b.mipmaps&&b.mipmaps.length>0){Y.__webglFramebuffer=[];for(let vt=0;vt<b.mipmaps.length;vt++)Y.__webglFramebuffer[vt]=n.createFramebuffer()}else Y.__webglFramebuffer=n.createFramebuffer();if(Ut)for(let vt=0,bt=ut.length;vt<bt;vt++){let ce=i.get(ut[vt]);ce.__webglTexture===void 0&&(ce.__webglTexture=n.createTexture(),a.memory.textures++)}if(I.samples>0&&At(I)===!1){Y.__webglMultisampledFramebuffer=n.createFramebuffer(),Y.__webglColorRenderbuffer=[],e.bindFramebuffer(n.FRAMEBUFFER,Y.__webglMultisampledFramebuffer);for(let vt=0;vt<ut.length;vt++){let bt=ut[vt];Y.__webglColorRenderbuffer[vt]=n.createRenderbuffer(),n.bindRenderbuffer(n.RENDERBUFFER,Y.__webglColorRenderbuffer[vt]);let ce=r.convert(bt.format,bt.colorSpace),gt=r.convert(bt.type),Pt=E(bt.internalFormat,ce,gt,bt.colorSpace,I.isXRRenderTarget===!0),Gt=pt(I);n.renderbufferStorageMultisample(n.RENDERBUFFER,Gt,Pt,I.width,I.height),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+vt,n.RENDERBUFFER,Y.__webglColorRenderbuffer[vt])}n.bindRenderbuffer(n.RENDERBUFFER,null),I.depthBuffer&&(Y.__webglDepthRenderbuffer=n.createRenderbuffer(),z(Y.__webglDepthRenderbuffer,I,!0)),e.bindFramebuffer(n.FRAMEBUFFER,null)}}if(st){e.bindTexture(n.TEXTURE_CUBE_MAP,it.__webglTexture),nt(n.TEXTURE_CUBE_MAP,b);for(let vt=0;vt<6;vt++)if(b.mipmaps&&b.mipmaps.length>0)for(let bt=0;bt<b.mipmaps.length;bt++)ct(Y.__webglFramebuffer[vt][bt],I,b,n.COLOR_ATTACHMENT0,n.TEXTURE_CUBE_MAP_POSITIVE_X+vt,bt);else ct(Y.__webglFramebuffer[vt],I,b,n.COLOR_ATTACHMENT0,n.TEXTURE_CUBE_MAP_POSITIVE_X+vt,0);m(b)&&p(n.TEXTURE_CUBE_MAP),e.unbindTexture()}else if(Ut){for(let vt=0,bt=ut.length;vt<bt;vt++){let ce=ut[vt],gt=i.get(ce);e.bindTexture(n.TEXTURE_2D,gt.__webglTexture),nt(n.TEXTURE_2D,ce),ct(Y.__webglFramebuffer,I,ce,n.COLOR_ATTACHMENT0+vt,n.TEXTURE_2D,0),m(ce)&&p(n.TEXTURE_2D)}e.unbindTexture()}else{let vt=n.TEXTURE_2D;if((I.isWebGL3DRenderTarget||I.isWebGLArrayRenderTarget)&&(vt=I.isWebGL3DRenderTarget?n.TEXTURE_3D:n.TEXTURE_2D_ARRAY),e.bindTexture(vt,it.__webglTexture),nt(vt,b),b.mipmaps&&b.mipmaps.length>0)for(let bt=0;bt<b.mipmaps.length;bt++)ct(Y.__webglFramebuffer[bt],I,b,n.COLOR_ATTACHMENT0,vt,bt);else ct(Y.__webglFramebuffer,I,b,n.COLOR_ATTACHMENT0,vt,0);m(b)&&p(vt),e.unbindTexture()}I.depthBuffer&&ft(I)}function Q(I){let b=I.textures;for(let Y=0,it=b.length;Y<it;Y++){let ut=b[Y];if(m(ut)){let st=S(I),Ut=i.get(ut).__webglTexture;e.bindTexture(st,Ut),p(st),e.unbindTexture()}}}let ht=[],L=[];function Nt(I){if(I.samples>0){if(At(I)===!1){let b=I.textures,Y=I.width,it=I.height,ut=n.COLOR_BUFFER_BIT,st=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,Ut=i.get(I),vt=b.length>1;if(vt)for(let bt=0;bt<b.length;bt++)e.bindFramebuffer(n.FRAMEBUFFER,Ut.__webglMultisampledFramebuffer),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+bt,n.RENDERBUFFER,null),e.bindFramebuffer(n.FRAMEBUFFER,Ut.__webglFramebuffer),n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0+bt,n.TEXTURE_2D,null,0);e.bindFramebuffer(n.READ_FRAMEBUFFER,Ut.__webglMultisampledFramebuffer),e.bindFramebuffer(n.DRAW_FRAMEBUFFER,Ut.__webglFramebuffer);for(let bt=0;bt<b.length;bt++){if(I.resolveDepthBuffer&&(I.depthBuffer&&(ut|=n.DEPTH_BUFFER_BIT),I.stencilBuffer&&I.resolveStencilBuffer&&(ut|=n.STENCIL_BUFFER_BIT)),vt){n.framebufferRenderbuffer(n.READ_FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.RENDERBUFFER,Ut.__webglColorRenderbuffer[bt]);let ce=i.get(b[bt]).__webglTexture;n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,ce,0)}n.blitFramebuffer(0,0,Y,it,0,0,Y,it,ut,n.NEAREST),l===!0&&(ht.length=0,L.length=0,ht.push(n.COLOR_ATTACHMENT0+bt),I.depthBuffer&&I.resolveDepthBuffer===!1&&(ht.push(st),L.push(st),n.invalidateFramebuffer(n.DRAW_FRAMEBUFFER,L)),n.invalidateFramebuffer(n.READ_FRAMEBUFFER,ht))}if(e.bindFramebuffer(n.READ_FRAMEBUFFER,null),e.bindFramebuffer(n.DRAW_FRAMEBUFFER,null),vt)for(let bt=0;bt<b.length;bt++){e.bindFramebuffer(n.FRAMEBUFFER,Ut.__webglMultisampledFramebuffer),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+bt,n.RENDERBUFFER,Ut.__webglColorRenderbuffer[bt]);let ce=i.get(b[bt]).__webglTexture;e.bindFramebuffer(n.FRAMEBUFFER,Ut.__webglFramebuffer),n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0+bt,n.TEXTURE_2D,ce,0)}e.bindFramebuffer(n.DRAW_FRAMEBUFFER,Ut.__webglMultisampledFramebuffer)}else if(I.depthBuffer&&I.resolveDepthBuffer===!1&&l){let b=I.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT;n.invalidateFramebuffer(n.DRAW_FRAMEBUFFER,[b])}}}function pt(I){return Math.min(s.maxSamples,I.samples)}function At(I){let b=i.get(I);return I.samples>0&&t.has("WEBGL_multisampled_render_to_texture")===!0&&b.__useRenderToTexture!==!1}function xt(I){let b=a.render.frame;h.get(I)!==b&&(h.set(I,b),I.update())}function Wt(I,b){let Y=I.colorSpace,it=I.format,ut=I.type;return I.isCompressedTexture===!0||I.isVideoTexture===!0||Y!==As&&Y!==Pi&&(pe.getTransfer(Y)===Me?(it!==Un||ut!==ai)&&console.warn("THREE.WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):console.error("THREE.WebGLTextures: Unsupported texture color space:",Y)),b}function wt(I){return typeof HTMLImageElement!="undefined"&&I instanceof HTMLImageElement?(c.width=I.naturalWidth||I.width,c.height=I.naturalHeight||I.height):typeof VideoFrame!="undefined"&&I instanceof VideoFrame?(c.width=I.displayWidth,c.height=I.displayHeight):(c.width=I.width,c.height=I.height),c}this.allocateTextureUnit=D,this.resetTextureUnits=P,this.setTexture2D=H,this.setTexture2DArray=U,this.setTexture3D=k,this.setTextureCube=F,this.rebindTextures=dt,this.setupRenderTarget=Ct,this.updateRenderTargetMipmap=Q,this.updateMultisampleRenderTarget=Nt,this.setupDepthRenderbuffer=ft,this.setupFrameBufferTexture=ct,this.useMultisampledRTT=At}function $y(n,t){function e(i,s=Pi){let r,a=pe.getTransfer(s);if(i===ai)return n.UNSIGNED_BYTE;if(i===ul)return n.UNSIGNED_SHORT_4_4_4_4;if(i===dl)return n.UNSIGNED_SHORT_5_5_5_1;if(i===rh)return n.UNSIGNED_INT_5_9_9_9_REV;if(i===ih)return n.BYTE;if(i===sh)return n.SHORT;if(i===_r)return n.UNSIGNED_SHORT;if(i===hl)return n.INT;if(i===ss)return n.UNSIGNED_INT;if(i===Yn)return n.FLOAT;if(i===vr)return n.HALF_FLOAT;if(i===oh)return n.ALPHA;if(i===ah)return n.RGB;if(i===Un)return n.RGBA;if(i===lh)return n.LUMINANCE;if(i===ch)return n.LUMINANCE_ALPHA;if(i===Ss)return n.DEPTH_COMPONENT;if(i===bs)return n.DEPTH_STENCIL;if(i===fl)return n.RED;if(i===pl)return n.RED_INTEGER;if(i===hh)return n.RG;if(i===ml)return n.RG_INTEGER;if(i===gl)return n.RGBA_INTEGER;if(i===To||i===bo||i===Ao||i===Ro)if(a===Me)if(r=t.get("WEBGL_compressed_texture_s3tc_srgb"),r!==null){if(i===To)return r.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(i===bo)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(i===Ao)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(i===Ro)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(r=t.get("WEBGL_compressed_texture_s3tc"),r!==null){if(i===To)return r.COMPRESSED_RGB_S3TC_DXT1_EXT;if(i===bo)return r.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(i===Ao)return r.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(i===Ro)return r.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(i===xl||i===yl||i===_l||i===vl)if(r=t.get("WEBGL_compressed_texture_pvrtc"),r!==null){if(i===xl)return r.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(i===yl)return r.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(i===_l)return r.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(i===vl)return r.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(i===Ml||i===El||i===Sl)if(r=t.get("WEBGL_compressed_texture_etc"),r!==null){if(i===Ml||i===El)return a===Me?r.COMPRESSED_SRGB8_ETC2:r.COMPRESSED_RGB8_ETC2;if(i===Sl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:r.COMPRESSED_RGBA8_ETC2_EAC}else return null;if(i===wl||i===Tl||i===bl||i===Al||i===Rl||i===Cl||i===Pl||i===Il||i===Ll||i===Dl||i===Ul||i===Nl||i===Fl||i===Ol)if(r=t.get("WEBGL_compressed_texture_astc"),r!==null){if(i===wl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:r.COMPRESSED_RGBA_ASTC_4x4_KHR;if(i===Tl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:r.COMPRESSED_RGBA_ASTC_5x4_KHR;if(i===bl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:r.COMPRESSED_RGBA_ASTC_5x5_KHR;if(i===Al)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:r.COMPRESSED_RGBA_ASTC_6x5_KHR;if(i===Rl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:r.COMPRESSED_RGBA_ASTC_6x6_KHR;if(i===Cl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:r.COMPRESSED_RGBA_ASTC_8x5_KHR;if(i===Pl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:r.COMPRESSED_RGBA_ASTC_8x6_KHR;if(i===Il)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:r.COMPRESSED_RGBA_ASTC_8x8_KHR;if(i===Ll)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:r.COMPRESSED_RGBA_ASTC_10x5_KHR;if(i===Dl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:r.COMPRESSED_RGBA_ASTC_10x6_KHR;if(i===Ul)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:r.COMPRESSED_RGBA_ASTC_10x8_KHR;if(i===Nl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:r.COMPRESSED_RGBA_ASTC_10x10_KHR;if(i===Fl)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:r.COMPRESSED_RGBA_ASTC_12x10_KHR;if(i===Ol)return a===Me?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:r.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(i===Co||i===Hl||i===Bl)if(r=t.get("EXT_texture_compression_bptc"),r!==null){if(i===Co)return a===Me?r.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:r.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(i===Hl)return r.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(i===Bl)return r.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(i===uh||i===kl||i===zl||i===Gl)if(r=t.get("EXT_texture_compression_rgtc"),r!==null){if(i===Co)return r.COMPRESSED_RED_RGTC1_EXT;if(i===kl)return r.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(i===zl)return r.COMPRESSED_RED_GREEN_RGTC2_EXT;if(i===Gl)return r.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return i===Us?n.UNSIGNED_INT_24_8:n[i]!==void 0?n[i]:null}return{convert:e}}var Zy={type:"move"},Io=class{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new he,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new he,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new O,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new O),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new he,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new O,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new O),this._grip}dispatchEvent(t){return this._targetRay!==null&&this._targetRay.dispatchEvent(t),this._grip!==null&&this._grip.dispatchEvent(t),this._hand!==null&&this._hand.dispatchEvent(t),this}connect(t){if(t&&t.hand){let e=this._hand;if(e)for(let i of t.hand.values())this._getHandJoint(e,i)}return this.dispatchEvent({type:"connected",data:t}),this}disconnect(t){return this.dispatchEvent({type:"disconnected",data:t}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(t,e,i){let s=null,r=null,a=null,o=this._targetRay,l=this._grip,c=this._hand;if(t&&e.session.visibilityState!=="visible-blurred"){if(c&&t.hand){a=!0;for(let M of t.hand.values()){let m=e.getJointPose(M,i),p=this._getHandJoint(c,M);m!==null&&(p.matrix.fromArray(m.transform.matrix),p.matrix.decompose(p.position,p.rotation,p.scale),p.matrixWorldNeedsUpdate=!0,p.jointRadius=m.radius),p.visible=m!==null}let h=c.joints["index-finger-tip"],d=c.joints["thumb-tip"],u=h.position.distanceTo(d.position),f=.02,x=.005;c.inputState.pinching&&u>f+x?(c.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:t.handedness,target:this})):!c.inputState.pinching&&u<=f-x&&(c.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:t.handedness,target:this}))}else l!==null&&t.gripSpace&&(r=e.getPose(t.gripSpace,i),r!==null&&(l.matrix.fromArray(r.transform.matrix),l.matrix.decompose(l.position,l.rotation,l.scale),l.matrixWorldNeedsUpdate=!0,r.linearVelocity?(l.hasLinearVelocity=!0,l.linearVelocity.copy(r.linearVelocity)):l.hasLinearVelocity=!1,r.angularVelocity?(l.hasAngularVelocity=!0,l.angularVelocity.copy(r.angularVelocity)):l.hasAngularVelocity=!1));o!==null&&(s=e.getPose(t.targetRaySpace,i),s===null&&r!==null&&(s=r),s!==null&&(o.matrix.fromArray(s.transform.matrix),o.matrix.decompose(o.position,o.rotation,o.scale),o.matrixWorldNeedsUpdate=!0,s.linearVelocity?(o.hasLinearVelocity=!0,o.linearVelocity.copy(s.linearVelocity)):o.hasLinearVelocity=!1,s.angularVelocity?(o.hasAngularVelocity=!0,o.angularVelocity.copy(s.angularVelocity)):o.hasAngularVelocity=!1,this.dispatchEvent(Zy)))}return o!==null&&(o.visible=s!==null),l!==null&&(l.visible=r!==null),c!==null&&(c.visible=a!==null),this}_getHandJoint(t,e){if(t.joints[e.jointName]===void 0){let i=new he;i.matrixAutoUpdate=!1,i.visible=!1,t.joints[e.jointName]=i,t.add(i)}return t.joints[e.jointName]}},Jy=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,Ky=`
uniform sampler2DArray depthColor;
uniform float depthWidth;
uniform float depthHeight;

void main() {

	vec2 coord = vec2( gl_FragCoord.x / depthWidth, gl_FragCoord.y / depthHeight );

	if ( coord.x >= 1.0 ) {

		gl_FragDepth = texture( depthColor, vec3( coord.x - 1.0, coord.y, 1 ) ).r;

	} else {

		gl_FragDepth = texture( depthColor, vec3( coord.x, coord.y, 0 ) ).r;

	}

}`,Lh=class{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(t,e,i){if(this.texture===null){let s=new an,r=t.properties.get(s);r.__webglTexture=e.texture,(e.depthNear!=i.depthNear||e.depthFar!=i.depthFar)&&(this.depthNear=e.depthNear,this.depthFar=e.depthFar),this.texture=s}}getMesh(t){if(this.texture!==null&&this.mesh===null){let e=t.cameras[0].viewport,i=new qn({vertexShader:Jy,fragmentShader:Ky,uniforms:{depthColor:{value:this.texture},depthWidth:{value:e.z},depthHeight:{value:e.w}}});this.mesh=new $(new we(20,20),i)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}},Dh=class extends wi{constructor(t,e){super();let i=this,s=null,r=1,a=null,o="local-floor",l=1,c=null,h=null,d=null,u=null,f=null,x=null,M=new Lh,m=e.getContextAttributes(),p=null,S=null,E=[],g=[],C=new at,A=null,_=new on;_.viewport=new Le;let T=new on;T.viewport=new Le;let v=[_,T],y=new Ja,w=null,P=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function(B){let Z=E[B];return Z===void 0&&(Z=new Io,E[B]=Z),Z.getTargetRaySpace()},this.getControllerGrip=function(B){let Z=E[B];return Z===void 0&&(Z=new Io,E[B]=Z),Z.getGripSpace()},this.getHand=function(B){let Z=E[B];return Z===void 0&&(Z=new Io,E[B]=Z),Z.getHandSpace()};function D(B){let Z=g.indexOf(B.inputSource);if(Z===-1)return;let ct=E[Z];ct!==void 0&&(ct.update(B.inputSource,B.frame,c||a),ct.dispatchEvent({type:B.type,data:B.inputSource}))}function N(){s.removeEventListener("select",D),s.removeEventListener("selectstart",D),s.removeEventListener("selectend",D),s.removeEventListener("squeeze",D),s.removeEventListener("squeezestart",D),s.removeEventListener("squeezeend",D),s.removeEventListener("end",N),s.removeEventListener("inputsourceschange",H);for(let B=0;B<E.length;B++){let Z=g[B];Z!==null&&(g[B]=null,E[B].disconnect(Z))}w=null,P=null,M.reset(),t.setRenderTarget(p),f=null,u=null,d=null,s=null,S=null,rt.stop(),i.isPresenting=!1,t.setPixelRatio(A),t.setSize(C.width,C.height,!1),i.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function(B){r=B,i.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function(B){o=B,i.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return c||a},this.setReferenceSpace=function(B){c=B},this.getBaseLayer=function(){return u!==null?u:f},this.getBinding=function(){return d},this.getFrame=function(){return x},this.getSession=function(){return s},this.setSession=async function(B){if(s=B,s!==null){if(p=t.getRenderTarget(),s.addEventListener("select",D),s.addEventListener("selectstart",D),s.addEventListener("selectend",D),s.addEventListener("squeeze",D),s.addEventListener("squeezestart",D),s.addEventListener("squeezeend",D),s.addEventListener("end",N),s.addEventListener("inputsourceschange",H),m.xrCompatible!==!0&&await e.makeXRCompatible(),A=t.getPixelRatio(),t.getSize(C),s.renderState.layers===void 0){let Z={antialias:m.antialias,alpha:!0,depth:m.depth,stencil:m.stencil,framebufferScaleFactor:r};f=new XRWebGLLayer(s,e,Z),s.updateRenderState({baseLayer:f}),t.setPixelRatio(1),t.setSize(f.framebufferWidth,f.framebufferHeight,!1),S=new ni(f.framebufferWidth,f.framebufferHeight,{format:Un,type:ai,colorSpace:t.outputColorSpace,stencilBuffer:m.stencil})}else{let Z=null,ct=null,z=null;m.depth&&(z=m.stencil?e.DEPTH24_STENCIL8:e.DEPTH_COMPONENT24,Z=m.stencil?bs:Ss,ct=m.stencil?Us:ss);let j={colorFormat:e.RGBA8,depthFormat:z,scaleFactor:r};d=new XRWebGLBinding(s,e),u=d.createProjectionLayer(j),s.updateRenderState({layers:[u]}),t.setPixelRatio(1),t.setSize(u.textureWidth,u.textureHeight,!1),S=new ni(u.textureWidth,u.textureHeight,{format:Un,type:ai,depthTexture:new so(u.textureWidth,u.textureHeight,ct,void 0,void 0,void 0,void 0,void 0,void 0,Z),stencilBuffer:m.stencil,colorSpace:t.outputColorSpace,samples:m.antialias?4:0,resolveDepthBuffer:u.ignoreDepthValues===!1})}S.isXRRenderTarget=!0,this.setFoveation(l),c=null,a=await s.requestReferenceSpace(o),rt.setContext(s),rt.start(),i.isPresenting=!0,i.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(s!==null)return s.environmentBlendMode},this.getDepthTexture=function(){return M.getDepthTexture()};function H(B){for(let Z=0;Z<B.removed.length;Z++){let ct=B.removed[Z],z=g.indexOf(ct);z>=0&&(g[z]=null,E[z].disconnect(ct))}for(let Z=0;Z<B.added.length;Z++){let ct=B.added[Z],z=g.indexOf(ct);if(z===-1){for(let ft=0;ft<E.length;ft++)if(ft>=g.length){g.push(ct),z=ft;break}else if(g[ft]===null){g[ft]=ct,z=ft;break}if(z===-1)break}let j=E[z];j&&j.connect(ct)}}let U=new O,k=new O;function F(B,Z,ct){U.setFromMatrixPosition(Z.matrixWorld),k.setFromMatrixPosition(ct.matrixWorld);let z=U.distanceTo(k),j=Z.projectionMatrix.elements,ft=ct.projectionMatrix.elements,dt=j[14]/(j[10]-1),Ct=j[14]/(j[10]+1),Q=(j[9]+1)/j[5],ht=(j[9]-1)/j[5],L=(j[8]-1)/j[0],Nt=(ft[8]+1)/ft[0],pt=dt*L,At=dt*Nt,xt=z/(-L+Nt),Wt=xt*-L;if(Z.matrixWorld.decompose(B.position,B.quaternion,B.scale),B.translateX(Wt),B.translateZ(xt),B.matrixWorld.compose(B.position,B.quaternion,B.scale),B.matrixWorldInverse.copy(B.matrixWorld).invert(),j[10]===-1)B.projectionMatrix.copy(Z.projectionMatrix),B.projectionMatrixInverse.copy(Z.projectionMatrixInverse);else{let wt=dt+xt,I=Ct+xt,b=pt-Wt,Y=At+(z-Wt),it=Q*Ct/I*wt,ut=ht*Ct/I*wt;B.projectionMatrix.makePerspective(b,Y,it,ut,wt,I),B.projectionMatrixInverse.copy(B.projectionMatrix).invert()}}function G(B,Z){Z===null?B.matrixWorld.copy(B.matrix):B.matrixWorld.multiplyMatrices(Z.matrixWorld,B.matrix),B.matrixWorldInverse.copy(B.matrixWorld).invert()}this.updateCamera=function(B){if(s===null)return;let Z=B.near,ct=B.far;M.texture!==null&&(M.depthNear>0&&(Z=M.depthNear),M.depthFar>0&&(ct=M.depthFar)),y.near=T.near=_.near=Z,y.far=T.far=_.far=ct,(w!==y.near||P!==y.far)&&(s.updateRenderState({depthNear:y.near,depthFar:y.far}),w=y.near,P=y.far),_.layers.mask=B.layers.mask|2,T.layers.mask=B.layers.mask|4,y.layers.mask=_.layers.mask|T.layers.mask;let z=B.parent,j=y.cameras;G(y,z);for(let ft=0;ft<j.length;ft++)G(j[ft],z);j.length===2?F(y,_,T):y.projectionMatrix.copy(_.projectionMatrix),q(B,y,z)};function q(B,Z,ct){ct===null?B.matrix.copy(Z.matrixWorld):(B.matrix.copy(ct.matrixWorld),B.matrix.invert(),B.matrix.multiply(Z.matrixWorld)),B.matrix.decompose(B.position,B.quaternion,B.scale),B.updateMatrixWorld(!0),B.projectionMatrix.copy(Z.projectionMatrix),B.projectionMatrixInverse.copy(Z.projectionMatrixInverse),B.isPerspectiveCamera&&(B.fov=ba*2*Math.atan(1/B.projectionMatrix.elements[5]),B.zoom=1)}this.getCamera=function(){return y},this.getFoveation=function(){if(!(u===null&&f===null))return l},this.setFoveation=function(B){l=B,u!==null&&(u.fixedFoveation=B),f!==null&&f.fixedFoveation!==void 0&&(f.fixedFoveation=B)},this.hasDepthSensing=function(){return M.texture!==null},this.getDepthSensingMesh=function(){return M.getMesh(y)};let et=null;function nt(B,Z){if(h=Z.getViewerPose(c||a),x=Z,h!==null){let ct=h.views;f!==null&&(t.setRenderTargetFramebuffer(S,f.framebuffer),t.setRenderTarget(S));let z=!1;ct.length!==y.cameras.length&&(y.cameras.length=0,z=!0);for(let ft=0;ft<ct.length;ft++){let dt=ct[ft],Ct=null;if(f!==null)Ct=f.getViewport(dt);else{let ht=d.getViewSubImage(u,dt);Ct=ht.viewport,ft===0&&(t.setRenderTargetTextures(S,ht.colorTexture,u.ignoreDepthValues?void 0:ht.depthStencilTexture),t.setRenderTarget(S))}let Q=v[ft];Q===void 0&&(Q=new on,Q.layers.enable(ft),Q.viewport=new Le,v[ft]=Q),Q.matrix.fromArray(dt.transform.matrix),Q.matrix.decompose(Q.position,Q.quaternion,Q.scale),Q.projectionMatrix.fromArray(dt.projectionMatrix),Q.projectionMatrixInverse.copy(Q.projectionMatrix).invert(),Q.viewport.set(Ct.x,Ct.y,Ct.width,Ct.height),ft===0&&(y.matrix.copy(Q.matrix),y.matrix.decompose(y.position,y.quaternion,y.scale)),z===!0&&y.cameras.push(Q)}let j=s.enabledFeatures;if(j&&j.includes("depth-sensing")){let ft=d.getDepthInformation(ct[0]);ft&&ft.isValid&&ft.texture&&M.init(t,ft,s.renderState)}}for(let ct=0;ct<E.length;ct++){let z=g[ct],j=E[ct];z!==null&&j!==void 0&&j.update(z,Z,c||a)}et&&et(B,Z),Z.detectedPlanes&&i.dispatchEvent({type:"planesdetected",data:Z}),x=null}let rt=new mf;rt.setAnimationLoop(nt),this.setAnimationLoop=function(B){et=B},this.dispose=function(){}}},Hs=new Ln,Qy=new be;function jy(n,t){function e(m,p){m.matrixAutoUpdate===!0&&m.updateMatrix(),p.value.copy(m.matrix)}function i(m,p){p.color.getRGB(m.fogColor.value,mh(n)),p.isFog?(m.fogNear.value=p.near,m.fogFar.value=p.far):p.isFogExp2&&(m.fogDensity.value=p.density)}function s(m,p,S,E,g){p.isMeshBasicMaterial||p.isMeshLambertMaterial?r(m,p):p.isMeshToonMaterial?(r(m,p),d(m,p)):p.isMeshPhongMaterial?(r(m,p),h(m,p)):p.isMeshStandardMaterial?(r(m,p),u(m,p),p.isMeshPhysicalMaterial&&f(m,p,g)):p.isMeshMatcapMaterial?(r(m,p),x(m,p)):p.isMeshDepthMaterial?r(m,p):p.isMeshDistanceMaterial?(r(m,p),M(m,p)):p.isMeshNormalMaterial?r(m,p):p.isLineBasicMaterial?(a(m,p),p.isLineDashedMaterial&&o(m,p)):p.isPointsMaterial?l(m,p,S,E):p.isSpriteMaterial?c(m,p):p.isShadowMaterial?(m.color.value.copy(p.color),m.opacity.value=p.opacity):p.isShaderMaterial&&(p.uniformsNeedUpdate=!1)}function r(m,p){m.opacity.value=p.opacity,p.color&&m.diffuse.value.copy(p.color),p.emissive&&m.emissive.value.copy(p.emissive).multiplyScalar(p.emissiveIntensity),p.map&&(m.map.value=p.map,e(p.map,m.mapTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.bumpMap&&(m.bumpMap.value=p.bumpMap,e(p.bumpMap,m.bumpMapTransform),m.bumpScale.value=p.bumpScale,p.side===je&&(m.bumpScale.value*=-1)),p.normalMap&&(m.normalMap.value=p.normalMap,e(p.normalMap,m.normalMapTransform),m.normalScale.value.copy(p.normalScale),p.side===je&&m.normalScale.value.negate()),p.displacementMap&&(m.displacementMap.value=p.displacementMap,e(p.displacementMap,m.displacementMapTransform),m.displacementScale.value=p.displacementScale,m.displacementBias.value=p.displacementBias),p.emissiveMap&&(m.emissiveMap.value=p.emissiveMap,e(p.emissiveMap,m.emissiveMapTransform)),p.specularMap&&(m.specularMap.value=p.specularMap,e(p.specularMap,m.specularMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest);let S=t.get(p),E=S.envMap,g=S.envMapRotation;E&&(m.envMap.value=E,Hs.copy(g),Hs.x*=-1,Hs.y*=-1,Hs.z*=-1,E.isCubeTexture&&E.isRenderTargetTexture===!1&&(Hs.y*=-1,Hs.z*=-1),m.envMapRotation.value.setFromMatrix4(Qy.makeRotationFromEuler(Hs)),m.flipEnvMap.value=E.isCubeTexture&&E.isRenderTargetTexture===!1?-1:1,m.reflectivity.value=p.reflectivity,m.ior.value=p.ior,m.refractionRatio.value=p.refractionRatio),p.lightMap&&(m.lightMap.value=p.lightMap,m.lightMapIntensity.value=p.lightMapIntensity,e(p.lightMap,m.lightMapTransform)),p.aoMap&&(m.aoMap.value=p.aoMap,m.aoMapIntensity.value=p.aoMapIntensity,e(p.aoMap,m.aoMapTransform))}function a(m,p){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,p.map&&(m.map.value=p.map,e(p.map,m.mapTransform))}function o(m,p){m.dashSize.value=p.dashSize,m.totalSize.value=p.dashSize+p.gapSize,m.scale.value=p.scale}function l(m,p,S,E){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,m.size.value=p.size*S,m.scale.value=E*.5,p.map&&(m.map.value=p.map,e(p.map,m.uvTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest)}function c(m,p){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,m.rotation.value=p.rotation,p.map&&(m.map.value=p.map,e(p.map,m.mapTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest)}function h(m,p){m.specular.value.copy(p.specular),m.shininess.value=Math.max(p.shininess,1e-4)}function d(m,p){p.gradientMap&&(m.gradientMap.value=p.gradientMap)}function u(m,p){m.metalness.value=p.metalness,p.metalnessMap&&(m.metalnessMap.value=p.metalnessMap,e(p.metalnessMap,m.metalnessMapTransform)),m.roughness.value=p.roughness,p.roughnessMap&&(m.roughnessMap.value=p.roughnessMap,e(p.roughnessMap,m.roughnessMapTransform)),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)}function f(m,p,S){m.ior.value=p.ior,p.sheen>0&&(m.sheenColor.value.copy(p.sheenColor).multiplyScalar(p.sheen),m.sheenRoughness.value=p.sheenRoughness,p.sheenColorMap&&(m.sheenColorMap.value=p.sheenColorMap,e(p.sheenColorMap,m.sheenColorMapTransform)),p.sheenRoughnessMap&&(m.sheenRoughnessMap.value=p.sheenRoughnessMap,e(p.sheenRoughnessMap,m.sheenRoughnessMapTransform))),p.clearcoat>0&&(m.clearcoat.value=p.clearcoat,m.clearcoatRoughness.value=p.clearcoatRoughness,p.clearcoatMap&&(m.clearcoatMap.value=p.clearcoatMap,e(p.clearcoatMap,m.clearcoatMapTransform)),p.clearcoatRoughnessMap&&(m.clearcoatRoughnessMap.value=p.clearcoatRoughnessMap,e(p.clearcoatRoughnessMap,m.clearcoatRoughnessMapTransform)),p.clearcoatNormalMap&&(m.clearcoatNormalMap.value=p.clearcoatNormalMap,e(p.clearcoatNormalMap,m.clearcoatNormalMapTransform),m.clearcoatNormalScale.value.copy(p.clearcoatNormalScale),p.side===je&&m.clearcoatNormalScale.value.negate())),p.dispersion>0&&(m.dispersion.value=p.dispersion),p.iridescence>0&&(m.iridescence.value=p.iridescence,m.iridescenceIOR.value=p.iridescenceIOR,m.iridescenceThicknessMinimum.value=p.iridescenceThicknessRange[0],m.iridescenceThicknessMaximum.value=p.iridescenceThicknessRange[1],p.iridescenceMap&&(m.iridescenceMap.value=p.iridescenceMap,e(p.iridescenceMap,m.iridescenceMapTransform)),p.iridescenceThicknessMap&&(m.iridescenceThicknessMap.value=p.iridescenceThicknessMap,e(p.iridescenceThicknessMap,m.iridescenceThicknessMapTransform))),p.transmission>0&&(m.transmission.value=p.transmission,m.transmissionSamplerMap.value=S.texture,m.transmissionSamplerSize.value.set(S.width,S.height),p.transmissionMap&&(m.transmissionMap.value=p.transmissionMap,e(p.transmissionMap,m.transmissionMapTransform)),m.thickness.value=p.thickness,p.thicknessMap&&(m.thicknessMap.value=p.thicknessMap,e(p.thicknessMap,m.thicknessMapTransform)),m.attenuationDistance.value=p.attenuationDistance,m.attenuationColor.value.copy(p.attenuationColor)),p.anisotropy>0&&(m.anisotropyVector.value.set(p.anisotropy*Math.cos(p.anisotropyRotation),p.anisotropy*Math.sin(p.anisotropyRotation)),p.anisotropyMap&&(m.anisotropyMap.value=p.anisotropyMap,e(p.anisotropyMap,m.anisotropyMapTransform))),m.specularIntensity.value=p.specularIntensity,m.specularColor.value.copy(p.specularColor),p.specularColorMap&&(m.specularColorMap.value=p.specularColorMap,e(p.specularColorMap,m.specularColorMapTransform)),p.specularIntensityMap&&(m.specularIntensityMap.value=p.specularIntensityMap,e(p.specularIntensityMap,m.specularIntensityMapTransform))}function x(m,p){p.matcap&&(m.matcap.value=p.matcap)}function M(m,p){let S=t.get(p).light;m.referencePosition.value.setFromMatrixPosition(S.matrixWorld),m.nearDistance.value=S.shadow.camera.near,m.farDistance.value=S.shadow.camera.far}return{refreshFogUniforms:i,refreshMaterialUniforms:s}}function t_(n,t,e,i){let s={},r={},a=[],o=n.getParameter(n.MAX_UNIFORM_BUFFER_BINDINGS);function l(S,E){let g=E.program;i.uniformBlockBinding(S,g)}function c(S,E){let g=s[S.id];g===void 0&&(x(S),g=h(S),s[S.id]=g,S.addEventListener("dispose",m));let C=E.program;i.updateUBOMapping(S,C);let A=t.render.frame;r[S.id]!==A&&(u(S),r[S.id]=A)}function h(S){let E=d();S.__bindingPointIndex=E;let g=n.createBuffer(),C=S.__size,A=S.usage;return n.bindBuffer(n.UNIFORM_BUFFER,g),n.bufferData(n.UNIFORM_BUFFER,C,A),n.bindBuffer(n.UNIFORM_BUFFER,null),n.bindBufferBase(n.UNIFORM_BUFFER,E,g),g}function d(){for(let S=0;S<o;S++)if(a.indexOf(S)===-1)return a.push(S),S;return console.error("THREE.WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function u(S){let E=s[S.id],g=S.uniforms,C=S.__cache;n.bindBuffer(n.UNIFORM_BUFFER,E);for(let A=0,_=g.length;A<_;A++){let T=Array.isArray(g[A])?g[A]:[g[A]];for(let v=0,y=T.length;v<y;v++){let w=T[v];if(f(w,A,v,C)===!0){let P=w.__offset,D=Array.isArray(w.value)?w.value:[w.value],N=0;for(let H=0;H<D.length;H++){let U=D[H],k=M(U);typeof U=="number"||typeof U=="boolean"?(w.__data[0]=U,n.bufferSubData(n.UNIFORM_BUFFER,P+N,w.__data)):U.isMatrix3?(w.__data[0]=U.elements[0],w.__data[1]=U.elements[1],w.__data[2]=U.elements[2],w.__data[3]=0,w.__data[4]=U.elements[3],w.__data[5]=U.elements[4],w.__data[6]=U.elements[5],w.__data[7]=0,w.__data[8]=U.elements[6],w.__data[9]=U.elements[7],w.__data[10]=U.elements[8],w.__data[11]=0):(U.toArray(w.__data,N),N+=k.storage/Float32Array.BYTES_PER_ELEMENT)}n.bufferSubData(n.UNIFORM_BUFFER,P,w.__data)}}}n.bindBuffer(n.UNIFORM_BUFFER,null)}function f(S,E,g,C){let A=S.value,_=E+"_"+g;if(C[_]===void 0)return typeof A=="number"||typeof A=="boolean"?C[_]=A:C[_]=A.clone(),!0;{let T=C[_];if(typeof A=="number"||typeof A=="boolean"){if(T!==A)return C[_]=A,!0}else if(T.equals(A)===!1)return T.copy(A),!0}return!1}function x(S){let E=S.uniforms,g=0,C=16;for(let _=0,T=E.length;_<T;_++){let v=Array.isArray(E[_])?E[_]:[E[_]];for(let y=0,w=v.length;y<w;y++){let P=v[y],D=Array.isArray(P.value)?P.value:[P.value];for(let N=0,H=D.length;N<H;N++){let U=D[N],k=M(U),F=g%C,G=F%k.boundary,q=F+G;g+=G,q!==0&&C-q<k.storage&&(g+=C-q),P.__data=new Float32Array(k.storage/Float32Array.BYTES_PER_ELEMENT),P.__offset=g,g+=k.storage}}}let A=g%C;return A>0&&(g+=C-A),S.__size=g,S.__cache={},this}function M(S){let E={boundary:0,storage:0};return typeof S=="number"||typeof S=="boolean"?(E.boundary=4,E.storage=4):S.isVector2?(E.boundary=8,E.storage=8):S.isVector3||S.isColor?(E.boundary=16,E.storage=12):S.isVector4?(E.boundary=16,E.storage=16):S.isMatrix3?(E.boundary=48,E.storage=48):S.isMatrix4?(E.boundary=64,E.storage=64):S.isTexture?console.warn("THREE.WebGLRenderer: Texture samplers can not be part of an uniforms group."):console.warn("THREE.WebGLRenderer: Unsupported uniform value type.",S),E}function m(S){let E=S.target;E.removeEventListener("dispose",m);let g=a.indexOf(E.__bindingPointIndex);a.splice(g,1),n.deleteBuffer(s[E.id]),delete s[E.id],delete r[E.id]}function p(){for(let S in s)n.deleteBuffer(s[S]);a=[],s={},r={}}return{bind:l,update:c,dispose:p}}var $l=class{constructor(t={}){let{canvas:e=Nd(),context:i=null,depth:s=!0,stencil:r=!1,alpha:a=!1,antialias:o=!1,premultipliedAlpha:l=!0,preserveDrawingBuffer:c=!1,powerPreference:h="default",failIfMajorPerformanceCaveat:d=!1,reverseDepthBuffer:u=!1}=t;this.isWebGLRenderer=!0;let f;if(i!==null){if(typeof WebGLRenderingContext!="undefined"&&i instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");f=i.getContextAttributes().alpha}else f=a;let x=new Uint32Array(4),M=new Int32Array(4),m=null,p=null,S=[],E=[];this.domElement=e,this.debug={checkShaderErrors:!0,onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this._outputColorSpace=Pe,this.toneMapping=Ci,this.toneMappingExposure=1;let g=this,C=!1,A=0,_=0,T=null,v=-1,y=null,w=new Le,P=new Le,D=null,N=new Ot(0),H=0,U=e.width,k=e.height,F=1,G=null,q=null,et=new Le(0,0,U,k),nt=new Le(0,0,U,k),rt=!1,B=new fr,Z=!1,ct=!1,z=new be,j=new be,ft=new O,dt=new Le,Ct={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0},Q=!1;function ht(){return T===null?F:1}let L=i;function Nt(R,W){return e.getContext(R,W)}try{let R={alpha:!0,depth:s,stencil:r,antialias:o,premultipliedAlpha:l,preserveDrawingBuffer:c,powerPreference:h,failIfMajorPerformanceCaveat:d};if("setAttribute"in e&&e.setAttribute("data-engine",`three.js r${"171"}`),e.addEventListener("webglcontextlost",ot,!1),e.addEventListener("webglcontextrestored",Tt,!1),e.addEventListener("webglcontextcreationerror",St,!1),L===null){let W="webgl2";if(L=Nt(W,R),L===null)throw Nt(W)?new Error("Error creating WebGL context with your selected attributes."):new Error("Error creating WebGL context.")}}catch(R){throw console.error("THREE.WebGLRenderer: "+R.message),R}let pt,At,xt,Wt,wt,I,b,Y,it,ut,st,Ut,vt,bt,ce,gt,Pt,Gt,Yt,It,ue,ee,Te,V;function Mt(){pt=new xx(L),pt.init(),ee=new $y(L,pt),At=new ux(L,pt,t,ee),xt=new qy(L,pt),At.reverseDepthBuffer&&u&&xt.buffers.depth.setReversed(!0),Wt=new vx(L),wt=new Dy,I=new Yy(L,pt,xt,wt,At,ee,Wt),b=new fx(g),Y=new gx(g),it=new Am(L),Te=new cx(L,it),ut=new yx(L,it,Wt,Te),st=new Ex(L,ut,it,Wt),Yt=new Mx(L,At,I),gt=new dx(wt),Ut=new Ly(g,b,Y,pt,At,Te,gt),vt=new jy(g,wt),bt=new Ny,ce=new zy(pt),Gt=new lx(g,b,Y,xt,st,f,l),Pt=new Wy(g,st,At),V=new t_(L,Wt,At,xt),It=new hx(L,pt,Wt),ue=new _x(L,pt,Wt),Wt.programs=Ut.programs,g.capabilities=At,g.extensions=pt,g.properties=wt,g.renderLists=bt,g.shadowMap=Pt,g.state=xt,g.info=Wt}Mt();let tt=new Dh(g,L);this.xr=tt,this.getContext=function(){return L},this.getContextAttributes=function(){return L.getContextAttributes()},this.forceContextLoss=function(){let R=pt.get("WEBGL_lose_context");R&&R.loseContext()},this.forceContextRestore=function(){let R=pt.get("WEBGL_lose_context");R&&R.restoreContext()},this.getPixelRatio=function(){return F},this.setPixelRatio=function(R){R!==void 0&&(F=R,this.setSize(U,k,!1))},this.getSize=function(R){return R.set(U,k)},this.setSize=function(R,W,J=!0){if(tt.isPresenting){console.warn("THREE.WebGLRenderer: Can't change size while VR device is presenting.");return}U=R,k=W,e.width=Math.floor(R*F),e.height=Math.floor(W*F),J===!0&&(e.style.width=R+"px",e.style.height=W+"px"),this.setViewport(0,0,R,W)},this.getDrawingBufferSize=function(R){return R.set(U*F,k*F).floor()},this.setDrawingBufferSize=function(R,W,J){U=R,k=W,F=J,e.width=Math.floor(R*J),e.height=Math.floor(W*J),this.setViewport(0,0,R,W)},this.getCurrentViewport=function(R){return R.copy(w)},this.getViewport=function(R){return R.copy(et)},this.setViewport=function(R,W,J,K){R.isVector4?et.set(R.x,R.y,R.z,R.w):et.set(R,W,J,K),xt.viewport(w.copy(et).multiplyScalar(F).round())},this.getScissor=function(R){return R.copy(nt)},this.setScissor=function(R,W,J,K){R.isVector4?nt.set(R.x,R.y,R.z,R.w):nt.set(R,W,J,K),xt.scissor(P.copy(nt).multiplyScalar(F).round())},this.getScissorTest=function(){return rt},this.setScissorTest=function(R){xt.setScissorTest(rt=R)},this.setOpaqueSort=function(R){G=R},this.setTransparentSort=function(R){q=R},this.getClearColor=function(R){return R.copy(Gt.getClearColor())},this.setClearColor=function(){Gt.setClearColor.apply(Gt,arguments)},this.getClearAlpha=function(){return Gt.getClearAlpha()},this.setClearAlpha=function(){Gt.setClearAlpha.apply(Gt,arguments)},this.clear=function(R=!0,W=!0,J=!0){let K=0;if(R){let X=!1;if(T!==null){let mt=T.texture.format;X=mt===gl||mt===ml||mt===pl}if(X){let mt=T.texture.type,Et=mt===ai||mt===ss||mt===_r||mt===Us||mt===ul||mt===dl,Rt=Gt.getClearColor(),Dt=Gt.getClearAlpha(),$t=Rt.r,Kt=Rt.g,kt=Rt.b;Et?(x[0]=$t,x[1]=Kt,x[2]=kt,x[3]=Dt,L.clearBufferuiv(L.COLOR,0,x)):(M[0]=$t,M[1]=Kt,M[2]=kt,M[3]=Dt,L.clearBufferiv(L.COLOR,0,M))}else K|=L.COLOR_BUFFER_BIT}W&&(K|=L.DEPTH_BUFFER_BIT),J&&(K|=L.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),L.clear(K)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.dispose=function(){e.removeEventListener("webglcontextlost",ot,!1),e.removeEventListener("webglcontextrestored",Tt,!1),e.removeEventListener("webglcontextcreationerror",St,!1),Gt.dispose(),bt.dispose(),ce.dispose(),wt.dispose(),b.dispose(),Y.dispose(),st.dispose(),Te.dispose(),V.dispose(),Ut.dispose(),tt.dispose(),tt.removeEventListener("sessionstart",yu),tt.removeEventListener("sessionend",_u),gs.stop()};function ot(R){R.preventDefault(),console.log("THREE.WebGLRenderer: Context Lost."),C=!0}function Tt(){console.log("THREE.WebGLRenderer: Context Restored."),C=!1;let R=Wt.autoReset,W=Pt.enabled,J=Pt.autoUpdate,K=Pt.needsUpdate,X=Pt.type;Mt(),Wt.autoReset=R,Pt.enabled=W,Pt.autoUpdate=J,Pt.needsUpdate=K,Pt.type=X}function St(R){console.error("THREE.WebGLRenderer: A WebGL context could not be created. Reason: ",R.statusMessage)}function jt(R){let W=R.target;W.removeEventListener("dispose",jt),Ne(W)}function Ne(R){nn(R),wt.remove(R)}function nn(R){let W=wt.get(R).programs;W!==void 0&&(W.forEach(function(J){Ut.releaseProgram(J)}),R.isShaderMaterial&&Ut.releaseShaderCache(R))}this.renderBufferDirect=function(R,W,J,K,X,mt){W===null&&(W=Ct);let Et=X.isMesh&&X.matrixWorld.determinant()<0,Rt=yp(R,W,J,K,X);xt.setMaterial(K,Et);let Dt=J.index,$t=1;if(K.wireframe===!0){if(Dt=ut.getWireframeAttribute(J),Dt===void 0)return;$t=2}let Kt=J.drawRange,kt=J.attributes.position,fe=Kt.start*$t,ge=(Kt.start+Kt.count)*$t;mt!==null&&(fe=Math.max(fe,mt.start*$t),ge=Math.min(ge,(mt.start+mt.count)*$t)),Dt!==null?(fe=Math.max(fe,0),ge=Math.min(ge,Dt.count)):kt!=null&&(fe=Math.max(fe,0),ge=Math.min(ge,kt.count));let Be=ge-fe;if(Be<0||Be===1/0)return;Te.setup(X,K,Rt,J,Dt);let Fe,me=It;if(Dt!==null&&(Fe=it.get(Dt),me=ue,me.setIndex(Fe)),X.isMesh)K.wireframe===!0?(xt.setLineWidth(K.wireframeLinewidth*ht()),me.setMode(L.LINES)):me.setMode(L.TRIANGLES);else if(X.isLine){let zt=K.linewidth;zt===void 0&&(zt=1),xt.setLineWidth(zt*ht()),X.isLineSegments?me.setMode(L.LINES):X.isLineLoop?me.setMode(L.LINE_LOOP):me.setMode(L.LINE_STRIP)}else X.isPoints?me.setMode(L.POINTS):X.isSprite&&me.setMode(L.TRIANGLES);if(X.isBatchedMesh)if(X._multiDrawInstances!==null)me.renderMultiDrawInstances(X._multiDrawStarts,X._multiDrawCounts,X._multiDrawCount,X._multiDrawInstances);else if(pt.get("WEBGL_multi_draw"))me.renderMultiDraw(X._multiDrawStarts,X._multiDrawCounts,X._multiDrawCount);else{let zt=X._multiDrawStarts,Ke=X._multiDrawCounts,xe=X._multiDrawCount,zn=Dt?it.get(Dt).bytesPerElement:1,$s=wt.get(K).currentProgram.getUniforms();for(let Sn=0;Sn<xe;Sn++)$s.setValue(L,"_gl_DrawID",Sn),me.render(zt[Sn]/zn,Ke[Sn])}else if(X.isInstancedMesh)me.renderInstances(fe,Be,X.count);else if(J.isInstancedBufferGeometry){let zt=J._maxInstanceCount!==void 0?J._maxInstanceCount:1/0,Ke=Math.min(J.instanceCount,zt);me.renderInstances(fe,Be,Ke)}else me.render(fe,Be)};function ve(R,W,J){R.transparent===!0&&R.side===Ce&&R.forceSinglePass===!1?(R.side=je,R.needsUpdate=!0,jo(R,W,J),R.side=Si,R.needsUpdate=!0,jo(R,W,J),R.side=Ce):jo(R,W,J)}this.compile=function(R,W,J=null){J===null&&(J=R),p=ce.get(J),p.init(W),E.push(p),J.traverseVisible(function(X){X.isLight&&X.layers.test(W.layers)&&(p.pushLight(X),X.castShadow&&p.pushShadow(X))}),R!==J&&R.traverseVisible(function(X){X.isLight&&X.layers.test(W.layers)&&(p.pushLight(X),X.castShadow&&p.pushShadow(X))}),p.setupLights();let K=new Set;return R.traverse(function(X){if(!(X.isMesh||X.isPoints||X.isLine||X.isSprite))return;let mt=X.material;if(mt)if(Array.isArray(mt))for(let Et=0;Et<mt.length;Et++){let Rt=mt[Et];ve(Rt,J,X),K.add(Rt)}else ve(mt,J,X),K.add(mt)}),E.pop(),p=null,K},this.compileAsync=function(R,W,J=null){let K=this.compile(R,W,J);return new Promise(X=>{function mt(){if(K.forEach(function(Et){wt.get(Et).currentProgram.isReady()&&K.delete(Et)}),K.size===0){X(R);return}setTimeout(mt,10)}pt.get("KHR_parallel_shader_compile")!==null?mt():setTimeout(mt,10)})};let kn=null;function mi(R){kn&&kn(R)}function yu(){gs.stop()}function _u(){gs.start()}let gs=new mf;gs.setAnimationLoop(mi),typeof self!="undefined"&&gs.setContext(self),this.setAnimationLoop=function(R){kn=R,tt.setAnimationLoop(R),R===null?gs.stop():gs.start()},tt.addEventListener("sessionstart",yu),tt.addEventListener("sessionend",_u),this.render=function(R,W){if(W!==void 0&&W.isCamera!==!0){console.error("THREE.WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(C===!0)return;if(R.matrixWorldAutoUpdate===!0&&R.updateMatrixWorld(),W.parent===null&&W.matrixWorldAutoUpdate===!0&&W.updateMatrixWorld(),tt.enabled===!0&&tt.isPresenting===!0&&(tt.cameraAutoUpdate===!0&&tt.updateCamera(W),W=tt.getCamera()),R.isScene===!0&&R.onBeforeRender(g,R,W,T),p=ce.get(R,E.length),p.init(W),E.push(p),j.multiplyMatrices(W.projectionMatrix,W.matrixWorldInverse),B.setFromProjectionMatrix(j),ct=this.localClippingEnabled,Z=gt.init(this.clippingPlanes,ct),m=bt.get(R,S.length),m.init(),S.push(m),tt.enabled===!0&&tt.isPresenting===!0){let mt=g.xr.getDepthSensingMesh();mt!==null&&fc(mt,W,-1/0,g.sortObjects)}fc(R,W,0,g.sortObjects),m.finish(),g.sortObjects===!0&&m.sort(G,q),Q=tt.enabled===!1||tt.isPresenting===!1||tt.hasDepthSensing()===!1,Q&&Gt.addToRenderList(m,R),this.info.render.frame++,Z===!0&&gt.beginShadows();let J=p.state.shadowsArray;Pt.render(J,R,W),Z===!0&&gt.endShadows(),this.info.autoReset===!0&&this.info.reset();let K=m.opaque,X=m.transmissive;if(p.setupLights(),W.isArrayCamera){let mt=W.cameras;if(X.length>0)for(let Et=0,Rt=mt.length;Et<Rt;Et++){let Dt=mt[Et];Mu(K,X,R,Dt)}Q&&Gt.render(R);for(let Et=0,Rt=mt.length;Et<Rt;Et++){let Dt=mt[Et];vu(m,R,Dt,Dt.viewport)}}else X.length>0&&Mu(K,X,R,W),Q&&Gt.render(R),vu(m,R,W);T!==null&&(I.updateMultisampleRenderTarget(T),I.updateRenderTargetMipmap(T)),R.isScene===!0&&R.onAfterRender(g,R,W),Te.resetDefaultState(),v=-1,y=null,E.pop(),E.length>0?(p=E[E.length-1],Z===!0&&gt.setGlobalState(g.clippingPlanes,p.state.camera)):p=null,S.pop(),S.length>0?m=S[S.length-1]:m=null};function fc(R,W,J,K){if(R.visible===!1)return;if(R.layers.test(W.layers)){if(R.isGroup)J=R.renderOrder;else if(R.isLOD)R.autoUpdate===!0&&R.update(W);else if(R.isLight)p.pushLight(R),R.castShadow&&p.pushShadow(R);else if(R.isSprite){if(!R.frustumCulled||B.intersectsSprite(R)){K&&dt.setFromMatrixPosition(R.matrixWorld).applyMatrix4(j);let Et=st.update(R),Rt=R.material;Rt.visible&&m.push(R,Et,Rt,J,dt.z,null)}}else if((R.isMesh||R.isLine||R.isPoints)&&(!R.frustumCulled||B.intersectsObject(R))){let Et=st.update(R),Rt=R.material;if(K&&(R.boundingSphere!==void 0?(R.boundingSphere===null&&R.computeBoundingSphere(),dt.copy(R.boundingSphere.center)):(Et.boundingSphere===null&&Et.computeBoundingSphere(),dt.copy(Et.boundingSphere.center)),dt.applyMatrix4(R.matrixWorld).applyMatrix4(j)),Array.isArray(Rt)){let Dt=Et.groups;for(let $t=0,Kt=Dt.length;$t<Kt;$t++){let kt=Dt[$t],fe=Rt[kt.materialIndex];fe&&fe.visible&&m.push(R,Et,fe,J,dt.z,kt)}}else Rt.visible&&m.push(R,Et,Rt,J,dt.z,null)}}let mt=R.children;for(let Et=0,Rt=mt.length;Et<Rt;Et++)fc(mt[Et],W,J,K)}function vu(R,W,J,K){let X=R.opaque,mt=R.transmissive,Et=R.transparent;p.setupLightsView(J),Z===!0&&gt.setGlobalState(g.clippingPlanes,J),K&&xt.viewport(w.copy(K)),X.length>0&&Qo(X,W,J),mt.length>0&&Qo(mt,W,J),Et.length>0&&Qo(Et,W,J),xt.buffers.depth.setTest(!0),xt.buffers.depth.setMask(!0),xt.buffers.color.setMask(!0),xt.setPolygonOffset(!1)}function Mu(R,W,J,K){if((J.isScene===!0?J.overrideMaterial:null)!==null)return;p.state.transmissionRenderTarget[K.id]===void 0&&(p.state.transmissionRenderTarget[K.id]=new ni(1,1,{generateMipmaps:!0,type:pt.has("EXT_color_buffer_half_float")||pt.has("EXT_color_buffer_float")?vr:ai,minFilter:is,samples:4,stencilBuffer:r,resolveDepthBuffer:!1,resolveStencilBuffer:!1,colorSpace:pe.workingColorSpace}));let mt=p.state.transmissionRenderTarget[K.id],Et=K.viewport||w;mt.setSize(Et.z,Et.w);let Rt=g.getRenderTarget();g.setRenderTarget(mt),g.getClearColor(N),H=g.getClearAlpha(),H<1&&g.setClearColor(16777215,.5),g.clear(),Q&&Gt.render(J);let Dt=g.toneMapping;g.toneMapping=Ci;let $t=K.viewport;if(K.viewport!==void 0&&(K.viewport=void 0),p.setupLightsView(K),Z===!0&&gt.setGlobalState(g.clippingPlanes,K),Qo(R,J,K),I.updateMultisampleRenderTarget(mt),I.updateRenderTargetMipmap(mt),pt.has("WEBGL_multisampled_render_to_texture")===!1){let Kt=!1;for(let kt=0,fe=W.length;kt<fe;kt++){let ge=W[kt],Be=ge.object,Fe=ge.geometry,me=ge.material,zt=ge.group;if(me.side===Ce&&Be.layers.test(K.layers)){let Ke=me.side;me.side=je,me.needsUpdate=!0,Eu(Be,J,K,Fe,me,zt),me.side=Ke,me.needsUpdate=!0,Kt=!0}}Kt===!0&&(I.updateMultisampleRenderTarget(mt),I.updateRenderTargetMipmap(mt))}g.setRenderTarget(Rt),g.setClearColor(N,H),$t!==void 0&&(K.viewport=$t),g.toneMapping=Dt}function Qo(R,W,J){let K=W.isScene===!0?W.overrideMaterial:null;for(let X=0,mt=R.length;X<mt;X++){let Et=R[X],Rt=Et.object,Dt=Et.geometry,$t=K===null?Et.material:K,Kt=Et.group;Rt.layers.test(J.layers)&&Eu(Rt,W,J,Dt,$t,Kt)}}function Eu(R,W,J,K,X,mt){R.onBeforeRender(g,W,J,K,X,mt),R.modelViewMatrix.multiplyMatrices(J.matrixWorldInverse,R.matrixWorld),R.normalMatrix.getNormalMatrix(R.modelViewMatrix),X.onBeforeRender(g,W,J,K,R,mt),X.transparent===!0&&X.side===Ce&&X.forceSinglePass===!1?(X.side=je,X.needsUpdate=!0,g.renderBufferDirect(J,W,K,X,R,mt),X.side=Si,X.needsUpdate=!0,g.renderBufferDirect(J,W,K,X,R,mt),X.side=Ce):g.renderBufferDirect(J,W,K,X,R,mt),R.onAfterRender(g,W,J,K,X,mt)}function jo(R,W,J){W.isScene!==!0&&(W=Ct);let K=wt.get(R),X=p.state.lights,mt=p.state.shadowsArray,Et=X.state.version,Rt=Ut.getParameters(R,X.state,mt,W,J),Dt=Ut.getProgramCacheKey(Rt),$t=K.programs;K.environment=R.isMeshStandardMaterial?W.environment:null,K.fog=W.fog,K.envMap=(R.isMeshStandardMaterial?Y:b).get(R.envMap||K.environment),K.envMapRotation=K.environment!==null&&R.envMap===null?W.environmentRotation:R.envMapRotation,$t===void 0&&(R.addEventListener("dispose",jt),$t=new Map,K.programs=$t);let Kt=$t.get(Dt);if(Kt!==void 0){if(K.currentProgram===Kt&&K.lightsStateVersion===Et)return wu(R,Rt),Kt}else Rt.uniforms=Ut.getUniforms(R),R.onBeforeCompile(Rt,g),Kt=Ut.acquireProgram(Rt,Dt),$t.set(Dt,Kt),K.uniforms=Rt.uniforms;let kt=K.uniforms;return(!R.isShaderMaterial&&!R.isRawShaderMaterial||R.clipping===!0)&&(kt.clippingPlanes=gt.uniform),wu(R,Rt),K.needsLights=vp(R),K.lightsStateVersion=Et,K.needsLights&&(kt.ambientLightColor.value=X.state.ambient,kt.lightProbe.value=X.state.probe,kt.directionalLights.value=X.state.directional,kt.directionalLightShadows.value=X.state.directionalShadow,kt.spotLights.value=X.state.spot,kt.spotLightShadows.value=X.state.spotShadow,kt.rectAreaLights.value=X.state.rectArea,kt.ltc_1.value=X.state.rectAreaLTC1,kt.ltc_2.value=X.state.rectAreaLTC2,kt.pointLights.value=X.state.point,kt.pointLightShadows.value=X.state.pointShadow,kt.hemisphereLights.value=X.state.hemi,kt.directionalShadowMap.value=X.state.directionalShadowMap,kt.directionalShadowMatrix.value=X.state.directionalShadowMatrix,kt.spotShadowMap.value=X.state.spotShadowMap,kt.spotLightMatrix.value=X.state.spotLightMatrix,kt.spotLightMap.value=X.state.spotLightMap,kt.pointShadowMap.value=X.state.pointShadowMap,kt.pointShadowMatrix.value=X.state.pointShadowMatrix),K.currentProgram=Kt,K.uniformsList=null,Kt}function Su(R){if(R.uniformsList===null){let W=R.currentProgram.getUniforms();R.uniformsList=wr.seqWithValue(W.seq,R.uniforms)}return R.uniformsList}function wu(R,W){let J=wt.get(R);J.outputColorSpace=W.outputColorSpace,J.batching=W.batching,J.batchingColor=W.batchingColor,J.instancing=W.instancing,J.instancingColor=W.instancingColor,J.instancingMorph=W.instancingMorph,J.skinning=W.skinning,J.morphTargets=W.morphTargets,J.morphNormals=W.morphNormals,J.morphColors=W.morphColors,J.morphTargetsCount=W.morphTargetsCount,J.numClippingPlanes=W.numClippingPlanes,J.numIntersection=W.numClipIntersection,J.vertexAlphas=W.vertexAlphas,J.vertexTangents=W.vertexTangents,J.toneMapping=W.toneMapping}function yp(R,W,J,K,X){W.isScene!==!0&&(W=Ct),I.resetTextureUnits();let mt=W.fog,Et=K.isMeshStandardMaterial?W.environment:null,Rt=T===null?g.outputColorSpace:T.isXRRenderTarget===!0?T.texture.colorSpace:As,Dt=(K.isMeshStandardMaterial?Y:b).get(K.envMap||Et),$t=K.vertexColors===!0&&!!J.attributes.color&&J.attributes.color.itemSize===4,Kt=!!J.attributes.tangent&&(!!K.normalMap||K.anisotropy>0),kt=!!J.morphAttributes.position,fe=!!J.morphAttributes.normal,ge=!!J.morphAttributes.color,Be=Ci;K.toneMapped&&(T===null||T.isXRRenderTarget===!0)&&(Be=g.toneMapping);let Fe=J.morphAttributes.position||J.morphAttributes.normal||J.morphAttributes.color,me=Fe!==void 0?Fe.length:0,zt=wt.get(K),Ke=p.state.lights;if(Z===!0&&(ct===!0||R!==y)){let hn=R===y&&K.id===v;gt.setState(K,R,hn)}let xe=!1;K.version===zt.__version?(zt.needsLights&&zt.lightsStateVersion!==Ke.state.version||zt.outputColorSpace!==Rt||X.isBatchedMesh&&zt.batching===!1||!X.isBatchedMesh&&zt.batching===!0||X.isBatchedMesh&&zt.batchingColor===!0&&X.colorTexture===null||X.isBatchedMesh&&zt.batchingColor===!1&&X.colorTexture!==null||X.isInstancedMesh&&zt.instancing===!1||!X.isInstancedMesh&&zt.instancing===!0||X.isSkinnedMesh&&zt.skinning===!1||!X.isSkinnedMesh&&zt.skinning===!0||X.isInstancedMesh&&zt.instancingColor===!0&&X.instanceColor===null||X.isInstancedMesh&&zt.instancingColor===!1&&X.instanceColor!==null||X.isInstancedMesh&&zt.instancingMorph===!0&&X.morphTexture===null||X.isInstancedMesh&&zt.instancingMorph===!1&&X.morphTexture!==null||zt.envMap!==Dt||K.fog===!0&&zt.fog!==mt||zt.numClippingPlanes!==void 0&&(zt.numClippingPlanes!==gt.numPlanes||zt.numIntersection!==gt.numIntersection)||zt.vertexAlphas!==$t||zt.vertexTangents!==Kt||zt.morphTargets!==kt||zt.morphNormals!==fe||zt.morphColors!==ge||zt.toneMapping!==Be||zt.morphTargetsCount!==me)&&(xe=!0):(xe=!0,zt.__version=K.version);let zn=zt.currentProgram;xe===!0&&(zn=jo(K,W,X));let $s=!1,Sn=!1,Fr=!1,Re=zn.getUniforms(),Cn=zt.uniforms;if(xt.useProgram(zn.program)&&($s=!0,Sn=!0,Fr=!0),K.id!==v&&(v=K.id,Sn=!0),$s||y!==R){xt.buffers.depth.getReversed()?(z.copy(R.projectionMatrix),Od(z),Hd(z),Re.setValue(L,"projectionMatrix",z)):Re.setValue(L,"projectionMatrix",R.projectionMatrix),Re.setValue(L,"viewMatrix",R.matrixWorldInverse);let pn=Re.map.cameraPosition;pn!==void 0&&pn.setValue(L,ft.setFromMatrixPosition(R.matrixWorld)),At.logarithmicDepthBuffer&&Re.setValue(L,"logDepthBufFC",2/(Math.log(R.far+1)/Math.LN2)),(K.isMeshPhongMaterial||K.isMeshToonMaterial||K.isMeshLambertMaterial||K.isMeshBasicMaterial||K.isMeshStandardMaterial||K.isShaderMaterial)&&Re.setValue(L,"isOrthographic",R.isOrthographicCamera===!0),y!==R&&(y=R,Sn=!0,Fr=!0)}if(X.isSkinnedMesh){Re.setOptional(L,X,"bindMatrix"),Re.setOptional(L,X,"bindMatrixInverse");let hn=X.skeleton;hn&&(hn.boneTexture===null&&hn.computeBoneTexture(),Re.setValue(L,"boneTexture",hn.boneTexture,I))}X.isBatchedMesh&&(Re.setOptional(L,X,"batchingTexture"),Re.setValue(L,"batchingTexture",X._matricesTexture,I),Re.setOptional(L,X,"batchingIdTexture"),Re.setValue(L,"batchingIdTexture",X._indirectTexture,I),Re.setOptional(L,X,"batchingColorTexture"),X._colorsTexture!==null&&Re.setValue(L,"batchingColorTexture",X._colorsTexture,I));let Pn=J.morphAttributes;if((Pn.position!==void 0||Pn.normal!==void 0||Pn.color!==void 0)&&Yt.update(X,J,zn),(Sn||zt.receiveShadow!==X.receiveShadow)&&(zt.receiveShadow=X.receiveShadow,Re.setValue(L,"receiveShadow",X.receiveShadow)),K.isMeshGouraudMaterial&&K.envMap!==null&&(Cn.envMap.value=Dt,Cn.flipEnvMap.value=Dt.isCubeTexture&&Dt.isRenderTargetTexture===!1?-1:1),K.isMeshStandardMaterial&&K.envMap===null&&W.environment!==null&&(Cn.envMapIntensity.value=W.environmentIntensity),Sn&&(Re.setValue(L,"toneMappingExposure",g.toneMappingExposure),zt.needsLights&&_p(Cn,Fr),mt&&K.fog===!0&&vt.refreshFogUniforms(Cn,mt),vt.refreshMaterialUniforms(Cn,K,F,k,p.state.transmissionRenderTarget[R.id]),wr.upload(L,Su(zt),Cn,I)),K.isShaderMaterial&&K.uniformsNeedUpdate===!0&&(wr.upload(L,Su(zt),Cn,I),K.uniformsNeedUpdate=!1),K.isSpriteMaterial&&Re.setValue(L,"center",X.center),Re.setValue(L,"modelViewMatrix",X.modelViewMatrix),Re.setValue(L,"normalMatrix",X.normalMatrix),Re.setValue(L,"modelMatrix",X.matrixWorld),K.isShaderMaterial||K.isRawShaderMaterial){let hn=K.uniformsGroups;for(let pn=0,pc=hn.length;pn<pc;pn++){let xs=hn[pn];V.update(xs,zn),V.bind(xs,zn)}}return zn}function _p(R,W){R.ambientLightColor.needsUpdate=W,R.lightProbe.needsUpdate=W,R.directionalLights.needsUpdate=W,R.directionalLightShadows.needsUpdate=W,R.pointLights.needsUpdate=W,R.pointLightShadows.needsUpdate=W,R.spotLights.needsUpdate=W,R.spotLightShadows.needsUpdate=W,R.rectAreaLights.needsUpdate=W,R.hemisphereLights.needsUpdate=W}function vp(R){return R.isMeshLambertMaterial||R.isMeshToonMaterial||R.isMeshPhongMaterial||R.isMeshStandardMaterial||R.isShadowMaterial||R.isShaderMaterial&&R.lights===!0}this.getActiveCubeFace=function(){return A},this.getActiveMipmapLevel=function(){return _},this.getRenderTarget=function(){return T},this.setRenderTargetTextures=function(R,W,J){wt.get(R.texture).__webglTexture=W,wt.get(R.depthTexture).__webglTexture=J;let K=wt.get(R);K.__hasExternalTextures=!0,K.__autoAllocateDepthBuffer=J===void 0,K.__autoAllocateDepthBuffer||pt.has("WEBGL_multisampled_render_to_texture")===!0&&(console.warn("THREE.WebGLRenderer: Render-to-texture extension was disabled because an external texture was provided"),K.__useRenderToTexture=!1)},this.setRenderTargetFramebuffer=function(R,W){let J=wt.get(R);J.__webglFramebuffer=W,J.__useDefaultFramebuffer=W===void 0},this.setRenderTarget=function(R,W=0,J=0){T=R,A=W,_=J;let K=!0,X=null,mt=!1,Et=!1;if(R){let Dt=wt.get(R);if(Dt.__useDefaultFramebuffer!==void 0)xt.bindFramebuffer(L.FRAMEBUFFER,null),K=!1;else if(Dt.__webglFramebuffer===void 0)I.setupRenderTarget(R);else if(Dt.__hasExternalTextures)I.rebindTextures(R,wt.get(R.texture).__webglTexture,wt.get(R.depthTexture).__webglTexture);else if(R.depthBuffer){let kt=R.depthTexture;if(Dt.__boundDepthTexture!==kt){if(kt!==null&&wt.has(kt)&&(R.width!==kt.image.width||R.height!==kt.image.height))throw new Error("WebGLRenderTarget: Attached DepthTexture is initialized to the incorrect size.");I.setupDepthRenderbuffer(R)}}let $t=R.texture;($t.isData3DTexture||$t.isDataArrayTexture||$t.isCompressedArrayTexture)&&(Et=!0);let Kt=wt.get(R).__webglFramebuffer;R.isWebGLCubeRenderTarget?(Array.isArray(Kt[W])?X=Kt[W][J]:X=Kt[W],mt=!0):R.samples>0&&I.useMultisampledRTT(R)===!1?X=wt.get(R).__webglMultisampledFramebuffer:Array.isArray(Kt)?X=Kt[J]:X=Kt,w.copy(R.viewport),P.copy(R.scissor),D=R.scissorTest}else w.copy(et).multiplyScalar(F).floor(),P.copy(nt).multiplyScalar(F).floor(),D=rt;if(xt.bindFramebuffer(L.FRAMEBUFFER,X)&&K&&xt.drawBuffers(R,X),xt.viewport(w),xt.scissor(P),xt.setScissorTest(D),mt){let Dt=wt.get(R.texture);L.framebufferTexture2D(L.FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_CUBE_MAP_POSITIVE_X+W,Dt.__webglTexture,J)}else if(Et){let Dt=wt.get(R.texture),$t=W||0;L.framebufferTextureLayer(L.FRAMEBUFFER,L.COLOR_ATTACHMENT0,Dt.__webglTexture,J||0,$t)}v=-1},this.readRenderTargetPixels=function(R,W,J,K,X,mt,Et){if(!(R&&R.isWebGLRenderTarget)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let Rt=wt.get(R).__webglFramebuffer;if(R.isWebGLCubeRenderTarget&&Et!==void 0&&(Rt=Rt[Et]),Rt){xt.bindFramebuffer(L.FRAMEBUFFER,Rt);try{let Dt=R.texture,$t=Dt.format,Kt=Dt.type;if(!At.textureFormatReadable($t)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(!At.textureTypeReadable(Kt)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}W>=0&&W<=R.width-K&&J>=0&&J<=R.height-X&&L.readPixels(W,J,K,X,ee.convert($t),ee.convert(Kt),mt)}finally{let Dt=T!==null?wt.get(T).__webglFramebuffer:null;xt.bindFramebuffer(L.FRAMEBUFFER,Dt)}}},this.readRenderTargetPixelsAsync=async function(R,W,J,K,X,mt,Et){if(!(R&&R.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let Rt=wt.get(R).__webglFramebuffer;if(R.isWebGLCubeRenderTarget&&Et!==void 0&&(Rt=Rt[Et]),Rt){let Dt=R.texture,$t=Dt.format,Kt=Dt.type;if(!At.textureFormatReadable($t))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(!At.textureTypeReadable(Kt))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");if(W>=0&&W<=R.width-K&&J>=0&&J<=R.height-X){xt.bindFramebuffer(L.FRAMEBUFFER,Rt);let kt=L.createBuffer();L.bindBuffer(L.PIXEL_PACK_BUFFER,kt),L.bufferData(L.PIXEL_PACK_BUFFER,mt.byteLength,L.STREAM_READ),L.readPixels(W,J,K,X,ee.convert($t),ee.convert(Kt),0);let fe=T!==null?wt.get(T).__webglFramebuffer:null;xt.bindFramebuffer(L.FRAMEBUFFER,fe);let ge=L.fenceSync(L.SYNC_GPU_COMMANDS_COMPLETE,0);return L.flush(),await Fd(L,ge,4),L.bindBuffer(L.PIXEL_PACK_BUFFER,kt),L.getBufferSubData(L.PIXEL_PACK_BUFFER,0,mt),L.deleteBuffer(kt),L.deleteSync(ge),mt}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")}},this.copyFramebufferToTexture=function(R,W=null,J=0){R.isTexture!==!0&&(Ns("WebGLRenderer: copyFramebufferToTexture function signature has changed."),W=arguments[0]||null,R=arguments[1]);let K=Math.pow(2,-J),X=Math.floor(R.image.width*K),mt=Math.floor(R.image.height*K),Et=W!==null?W.x:0,Rt=W!==null?W.y:0;I.setTexture2D(R,0),L.copyTexSubImage2D(L.TEXTURE_2D,J,0,0,Et,Rt,X,mt),xt.unbindTexture()};let Mp=L.createFramebuffer(),Ep=L.createFramebuffer();this.copyTextureToTexture=function(R,W,J=null,K=null,X=0,mt=null){R.isTexture!==!0&&(Ns("WebGLRenderer: copyTextureToTexture function signature has changed."),K=arguments[0]||null,R=arguments[1],W=arguments[2],mt=arguments[3]||0,J=null),mt===null&&(X!==0?(Ns("WebGLRenderer: copyTextureToTexture function signature has changed to support src and dst mipmap levels."),mt=X,X=0):mt=0);let Et,Rt,Dt,$t,Kt,kt,fe,ge,Be,Fe=R.isCompressedTexture?R.mipmaps[mt]:R.image;if(J!==null)Et=J.max.x-J.min.x,Rt=J.max.y-J.min.y,Dt=J.isBox3?J.max.z-J.min.z:1,$t=J.min.x,Kt=J.min.y,kt=J.isBox3?J.min.z:0;else{let Pn=Math.pow(2,-X);Et=Math.floor(Fe.width*Pn),Rt=Math.floor(Fe.height*Pn),R.isDataArrayTexture?Dt=Fe.depth:R.isData3DTexture?Dt=Math.floor(Fe.depth*Pn):Dt=1,$t=0,Kt=0,kt=0}K!==null?(fe=K.x,ge=K.y,Be=K.z):(fe=0,ge=0,Be=0);let me=ee.convert(W.format),zt=ee.convert(W.type),Ke;W.isData3DTexture?(I.setTexture3D(W,0),Ke=L.TEXTURE_3D):W.isDataArrayTexture||W.isCompressedArrayTexture?(I.setTexture2DArray(W,0),Ke=L.TEXTURE_2D_ARRAY):(I.setTexture2D(W,0),Ke=L.TEXTURE_2D),L.pixelStorei(L.UNPACK_FLIP_Y_WEBGL,W.flipY),L.pixelStorei(L.UNPACK_PREMULTIPLY_ALPHA_WEBGL,W.premultiplyAlpha),L.pixelStorei(L.UNPACK_ALIGNMENT,W.unpackAlignment);let xe=L.getParameter(L.UNPACK_ROW_LENGTH),zn=L.getParameter(L.UNPACK_IMAGE_HEIGHT),$s=L.getParameter(L.UNPACK_SKIP_PIXELS),Sn=L.getParameter(L.UNPACK_SKIP_ROWS),Fr=L.getParameter(L.UNPACK_SKIP_IMAGES);L.pixelStorei(L.UNPACK_ROW_LENGTH,Fe.width),L.pixelStorei(L.UNPACK_IMAGE_HEIGHT,Fe.height),L.pixelStorei(L.UNPACK_SKIP_PIXELS,$t),L.pixelStorei(L.UNPACK_SKIP_ROWS,Kt),L.pixelStorei(L.UNPACK_SKIP_IMAGES,kt);let Re=R.isDataArrayTexture||R.isData3DTexture,Cn=W.isDataArrayTexture||W.isData3DTexture;if(R.isDepthTexture){let Pn=wt.get(R),hn=wt.get(W),pn=wt.get(Pn.__renderTarget),pc=wt.get(hn.__renderTarget);xt.bindFramebuffer(L.READ_FRAMEBUFFER,pn.__webglFramebuffer),xt.bindFramebuffer(L.DRAW_FRAMEBUFFER,pc.__webglFramebuffer);for(let xs=0;xs<Dt;xs++)Re&&(L.framebufferTextureLayer(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,wt.get(R).__webglTexture,X,kt+xs),L.framebufferTextureLayer(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,wt.get(W).__webglTexture,mt,Be+xs)),L.blitFramebuffer($t,Kt,Et,Rt,fe,ge,Et,Rt,L.DEPTH_BUFFER_BIT,L.NEAREST);xt.bindFramebuffer(L.READ_FRAMEBUFFER,null),xt.bindFramebuffer(L.DRAW_FRAMEBUFFER,null)}else if(X!==0||R.isRenderTargetTexture||wt.has(R)){let Pn=wt.get(R),hn=wt.get(W);xt.bindFramebuffer(L.READ_FRAMEBUFFER,Mp),xt.bindFramebuffer(L.DRAW_FRAMEBUFFER,Ep);for(let pn=0;pn<Dt;pn++)Re?L.framebufferTextureLayer(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,Pn.__webglTexture,X,kt+pn):L.framebufferTexture2D(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_2D,Pn.__webglTexture,X),Cn?L.framebufferTextureLayer(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,hn.__webglTexture,mt,Be+pn):L.framebufferTexture2D(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_2D,hn.__webglTexture,mt),X!==0?L.blitFramebuffer($t,Kt,Et,Rt,fe,ge,Et,Rt,L.COLOR_BUFFER_BIT,L.NEAREST):Cn?L.copyTexSubImage3D(Ke,mt,fe,ge,Be+pn,$t,Kt,Et,Rt):L.copyTexSubImage2D(Ke,mt,fe,ge,$t,Kt,Et,Rt);xt.bindFramebuffer(L.READ_FRAMEBUFFER,null),xt.bindFramebuffer(L.DRAW_FRAMEBUFFER,null)}else Cn?R.isDataTexture||R.isData3DTexture?L.texSubImage3D(Ke,mt,fe,ge,Be,Et,Rt,Dt,me,zt,Fe.data):W.isCompressedArrayTexture?L.compressedTexSubImage3D(Ke,mt,fe,ge,Be,Et,Rt,Dt,me,Fe.data):L.texSubImage3D(Ke,mt,fe,ge,Be,Et,Rt,Dt,me,zt,Fe):R.isDataTexture?L.texSubImage2D(L.TEXTURE_2D,mt,fe,ge,Et,Rt,me,zt,Fe.data):R.isCompressedTexture?L.compressedTexSubImage2D(L.TEXTURE_2D,mt,fe,ge,Fe.width,Fe.height,me,Fe.data):L.texSubImage2D(L.TEXTURE_2D,mt,fe,ge,Et,Rt,me,zt,Fe);L.pixelStorei(L.UNPACK_ROW_LENGTH,xe),L.pixelStorei(L.UNPACK_IMAGE_HEIGHT,zn),L.pixelStorei(L.UNPACK_SKIP_PIXELS,$s),L.pixelStorei(L.UNPACK_SKIP_ROWS,Sn),L.pixelStorei(L.UNPACK_SKIP_IMAGES,Fr),mt===0&&W.generateMipmaps&&L.generateMipmap(Ke),xt.unbindTexture()},this.copyTextureToTexture3D=function(R,W,J=null,K=null,X=0){return R.isTexture!==!0&&(Ns("WebGLRenderer: copyTextureToTexture3D function signature has changed."),J=arguments[0]||null,K=arguments[1]||null,R=arguments[2],W=arguments[3],X=arguments[4]||0),Ns('WebGLRenderer: copyTextureToTexture3D function has been deprecated. Use "copyTextureToTexture" instead.'),this.copyTextureToTexture(R,W,J,K,X)},this.initRenderTarget=function(R){wt.get(R).__webglFramebuffer===void 0&&I.setupRenderTarget(R)},this.initTexture=function(R){R.isCubeTexture?I.setTextureCube(R,0):R.isData3DTexture?I.setTexture3D(R,0):R.isDataArrayTexture||R.isCompressedArrayTexture?I.setTexture2DArray(R,0):I.setTexture2D(R,0),xt.unbindTexture()},this.resetState=function(){A=0,_=0,T=null,xt.reset(),Te.reset()},typeof __THREE_DEVTOOLS__!="undefined"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return ei}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(t){this._outputColorSpace=t;let e=this.getContext();e.drawingBufferColorspace=pe._getDrawingBufferColorSpace(t),e.unpackColorSpace=pe._getUnpackColorSpace()}};var vf={meadow:{turf:[70,172,62],turfAlt:[62,158,56],fog:14280902,hemiSky:15004159,hemiGround:7311167,sun:16773330,leaves:[6000430,7118388,4880936,8824892,7313964],ground:["#5e9436","#6aa03c","#7aa942","#53862f","#8fb04a"],trunk:7031342,flowers:[16777215,16773800,16765503,16095936,11832560,16739162,9423359],grass:[4160810,5148464,6003766],surface:"grass",surfRough:.96,wall:"woodstone",style:"meadow",water:["#3f8fc0","#2f6f9e"],accent:"#ffd646",kick:["#e0402f","#ffcf3a"]},bluffs:{surface:"slate",surfRough:.62,wall:"granite",style:"coast",water:["#0f6f8c","#08465c"],accent:"#7fe3ff",kick:["#2f6fc4","#f4f6f8"],turf:[96,142,166],turfAlt:[104,152,176],fog:13625072,hemiSky:14676735,hemiGround:7309914,sun:16774884,leaves:[7311162,8231488,6192948,13218362,9413960],trunk:8022616,ground:["#7a9a4a","#8aa652","#6e8e45","#9caf5c","#a9a27a"],flowers:[15182272,15906508,16767050,16769658,16777215,14258096],grass:[8231494,9414736,10988394],wallStone:"#b9bcb6",wallCap:"#d8dad4"}};function Mf(n){let{scene:t,cellAt:e,bx0:i,bx1:s,by0:r,by1:a,theme:o,seed:l=99}=n,c=l,h=()=>(c=c*16807%2147483647,c/2147483647),d=(z,j,ft)=>{if(e(z,j))return!1;for(let dt=0;dt<8;dt++){let Ct=Math.cos(dt*Math.PI/4)*ft,Q=Math.sin(dt*Math.PI/4)*ft;if(e(z+Ct,j+Q))return!1}for(let dt=0;dt<8;dt++){let Ct=Math.cos(dt*Math.PI/4+.4)*ft*.5,Q=Math.sin(dt*Math.PI/4+.4)*ft*.5;if(e(z+Ct,j+Q))return!1}return!0},u=new Oe,f=new Ot,x=z=>z[Math.floor(h()*z.length)],M=[];if(o.style==="coast")return e_({...n,rnd:h,clearOf:d,dummy:u,col:f,pick:x,upd:M});let m=[];for(let z=0;z<900&&m.length<26;z++){let j=h(),ft,dt;j<.55?(dt=r-6+h()*(a-r+6)*.95,ft=h()<.5?i-10-h()*45:s+10+h()*45):(ft=i-40+h()*(s-i+80),dt=r-12-h()*60),d(ft,dt,11)&&(m.some(Ct=>Math.hypot(Ct.x-ft,Ct.y-dt)<12)||m.push({x:ft,y:dt,h:9+h()*9,r:5+h()*4}))}let p=new Ai(1,1),S=new Lt({roughness:.9,flatShading:!0}),E=m.length*6,g=new He(p,S,Math.max(1,E));g.castShadow=!0,g.receiveShadow=!0;let C=new oe(.55,.9,1,7),A=new He(C,new Lt({color:o.trunk,roughness:1}),Math.max(1,m.length));A.castShadow=!0;let _=0;m.forEach((z,j)=>{u.position.set(z.x,z.h/2,z.y),u.scale.set(1,z.h,1),u.rotation.set(0,0,0),u.updateMatrix(),A.setMatrixAt(j,u.matrix);let ft=new Ot(x(o.leaves));for(let dt=0;dt<6;dt++){let Ct=h()*6.28,Q=dt===0?0:z.r*(.35+h()*.4),ht=z.r*(dt===0?1:.55+h()*.35);u.position.set(z.x+Math.cos(Ct)*Q,z.h+(dt===0?0:(h()-.2)*z.r*.7),z.y+Math.sin(Ct)*Q*.8),u.scale.setScalar(ht),u.updateMatrix(),g.setMatrixAt(_,u.matrix),f.copy(ft).offsetHSL((h()-.5)*.03,(h()-.5)*.1,(h()-.3)*.08),g.setColorAt(_,f),_++}}),g.count=_,t.add(g,A);let T=[];for(let z=0;z<3e3&&T.length<70;z++){let j=i-14+h()*(s-i+28),ft=r-14+h()*(a-r+18);!d(j,ft,3.2)||d(j,ft,9)||T.push({x:j,y:ft,r:1.4+h()*1.8})}let v=new He(p,S,Math.max(1,T.length*2));v.castShadow=!0,v.receiveShadow=!0;let y=0;for(let z of T)for(let j=0;j<2;j++)u.position.set(z.x+(j?(h()-.5)*z.r:0),z.r*.55,z.y+(j?(h()-.5)*z.r:0)),u.scale.set(z.r*(j?.7:1),z.r*(j?.6:.8),z.r*(j?.7:1)),u.updateMatrix(),v.setMatrixAt(y,u.matrix),f.set(x(o.leaves)).offsetHSL(0,0,(h()-.5)*.08),v.setColorAt(y,f),y++;v.count=y,t.add(v);let w=[],P=[];for(let z=0;z<1200&&P.length<46;z++){let j=i-40+h()*(s-i+80),ft=r-50+h()*(a-r+90);d(j,ft,3)&&P.push({x:j,y:ft,c:x(o.flowers)})}for(let z of P)for(let j=0;j<22;j++){let ft=h()*6.28,dt=Math.sqrt(h())*5,Ct=z.x+Math.cos(ft)*dt,Q=z.y+Math.sin(ft)*dt;d(Ct,Q,1.6)&&w.push({x:Ct,y:Q,c:h()<.8?z.c:x(o.flowers)})}if(n.bedFlowers!==!1)for(let z of n.roughs||[])for(let j=0;j<z.hw*z.hh*.9;j++){let ft=(h()*2-1)*z.hw*.92,dt=(h()*2-1)*z.hh*.92;w.push({x:z.x+ft*z.c-dt*z.s,y:z.y+ft*z.s+dt*z.c,c:x(o.flowers),onTurf:!0})}let D=new oe(.5,.42,.25,6),N=new He(D,new Lt({roughness:.7,emissive:1118481}),Math.max(1,w.length));w.forEach((z,j)=>{u.position.set(z.x,(z.onTurf?.5:.35)+h()*.5,z.y),u.rotation.set((h()-.5)*.4,0,(h()-.5)*.4),u.scale.setScalar(.7+h()*.6),u.updateMatrix(),N.setMatrixAt(j,u.matrix),f.set(z.c),N.setColorAt(j,f)}),t.add(N);let H=[];for(let z=0;z<9e3&&H.length<1600;z++){let j=i-45+h()*(s-i+90),ft=r-55+h()*(a-r+100);d(j,ft,1.8)&&H.push([j,ft])}let U=new un(.32,1.5,4);U.translate(0,.75,0);let k=new He(U,new Lt({roughness:1}),Math.max(1,H.length));H.forEach(([z,j],ft)=>{u.position.set(z,0,j),u.rotation.set((h()-.5)*.5,h()*3,(h()-.5)*.5),u.scale.set(1,.6+h()*.9,1),u.updateMatrix(),k.setMatrixAt(ft,u.matrix),f.set(x(o.grass)).offsetHSL(0,0,(h()-.5)*.1),k.setColorAt(ft,f)}),k.receiveShadow=!0,t.add(k);let F=new Cs(1,0),G=new He(F,new Lt({color:10131082,roughness:.95,flatShading:!0}),14),q=0;for(let z=0;z<800&&q<14;z++){let j=i-20+h()*(s-i+40),ft=r-20+h()*(a-r+30);if(!d(j,ft,4))continue;let dt=.8+h()*1.6;u.position.set(j,dt*.35,ft),u.rotation.set(h()*3,h()*3,h()*3),u.scale.set(dt*1.3,dt*.8,dt),u.updateMatrix(),G.setMatrixAt(q++,u.matrix)}G.count=q,G.castShadow=!0,t.add(G);let et=z=>new Lt({color:z,side:Ce,roughness:.6,emissive:z,emissiveIntensity:.15}),nt=[];for(let z=0;z<Math.min(9,P.length);z++){let j=P[Math.floor(h()*P.length)],ft=new he,dt=et(x([16757575,16773242,15790335,10474495,16748465])),Ct=new yn(.9,8);Ct.translate(.8,0,0);let Q=new $(Ct,dt),ht=new $(Ct,dt);ht.rotation.y=Math.PI,ft.add(Q,ht),ft.scale.setScalar(1.3),t.add(ft),nt.push({g:ft,L:Q,R:ht,cx:j.x,cy:j.y,ph:h()*6,sp:.4+h()*.4,rad:4+h()*7})}M.push(z=>{for(let j of nt){let ft=z*j.sp+j.ph,dt=j.cx+Math.cos(ft)*j.rad,Ct=j.cy+Math.sin(ft*1.3)*j.rad*.7;j.g.position.set(dt,3.5+Math.sin(ft*3)*1.2,Ct),j.g.rotation.y=-ft;let Q=Math.sin(z*18+j.ph)*.9;j.L.rotation.x=0,j.L.rotation.z=Q,j.R.rotation.z=-Q}});let rt=document.createElement("canvas");rt.width=rt.height=256;let B=rt.getContext("2d");B.fillStyle="#000",B.fillRect(0,0,256,256);for(let z=0;z<7;z++){let j=h()*256,ft=h()*256,dt=40+h()*50,Ct=B.createRadialGradient(j,ft,0,j,ft,dt);Ct.addColorStop(0,"rgba(255,255,255,.9)"),Ct.addColorStop(1,"rgba(255,255,255,0)"),B.fillStyle=Ct;for(let Q of[-256,0,256])for(let ht of[-256,0,256])B.save(),B.translate(Q,ht),B.beginPath(),B.arc(j,ft,dt,0,7),B.fill(),B.restore()}let Z=new Qe(rt);Z.wrapS=Z.wrapT=Ge,Z.repeat.set(2,2);let ct=new $(new we(600,700),new Se({color:662032,alphaMap:Z,transparent:!0,opacity:.2,depthWrite:!1}));return ct.rotation.x=-Math.PI/2,ct.position.set((i+s)/2,.08,(r+a)/2),ct.renderOrder=2,t.add(ct),M.push(z=>{Z.offset.set(z*.006,z*.004)}),{update:z=>{for(let j of M)j(z)}}}function Ef(n,t,e,i=7){let s=i,r=()=>(s=s*16807%2147483647,s/2147483647),a=document.createElement("canvas");a.width=t,a.height=e;let o=a.getContext("2d");o.fillStyle=n.ground[0],o.fillRect(0,0,t,e);for(let l=0;l<260;l++){let c=r()*t,h=r()*e,d=30+r()*140,u=n.ground[1+Math.floor(r()*(n.ground.length-1))],f=o.createRadialGradient(c,h,0,c,h,d);f.addColorStop(0,u+"aa"),f.addColorStop(1,u+"00"),o.fillStyle=f,o.beginPath(),o.ellipse(c,h,d*1.6,d,r()*3,0,7),o.fill()}for(let l=0;l<t*e/40;l++){let c=r()*t,h=r()*e;o.strokeStyle=r()<.5?"rgba(30,70,15,.18)":"rgba(210,240,150,.12)",o.lineWidth=1.2,o.beginPath(),o.moveTo(c,h),o.lineTo(c+(r()-.5)*3,h-3-r()*4),o.stroke()}for(let l=0;l<t*e/900;l++){let c=r()*t,h=r()*e;o.fillStyle=["#ffffff","#fff3a0","#f7b2d0","#c8b0ff"][Math.floor(r()*4)],o.globalAlpha=.75,o.beginPath(),o.arc(c,h,1+r()*1.6,0,7),o.fill()}return o.globalAlpha=1,a}function e_({scene:n,bx0:t,bx1:e,by0:i,by1:s,theme:r,rnd:a,clearOf:o,dummy:l,col:c,pick:h,upd:d}){let u=(nt,rt,B,Z,ct,z,j,ft)=>{let dt=0;for(let Ct=0;Ct<rt&&dt<nt;Ct++){let Q=B+a()*(Z-B),ht=ct+a()*(z-ct);o(Q,ht,j)&&(ft(Q,ht,dt),dt++)}return dt},f=new Ai(1,0),x=new He(f,new Lt({roughness:.92,flatShading:!0}),70),M=0;u(26,2e3,t-50,e+50,i-60,s+10,7,(nt,rt)=>{let B=1+Math.floor(a()*3);for(let Z=0;Z<B&&M<70;Z++){let ct=1.6+a()*3.6;l.position.set(nt+(a()-.5)*5,ct*.35,rt+(a()-.5)*4),l.rotation.set(a()*3,a()*3,a()*3),l.scale.set(ct*(1+a()*.5),ct*(.6+a()*.4),ct),l.updateMatrix(),x.setMatrixAt(M,l.matrix),c.setRGB(.6+a()*.12,.6+a()*.1,.56+a()*.08),x.setColorAt(M++,c)}}),x.count=M,x.castShadow=x.receiveShadow=!0,n.add(x);let m=new Ai(1,1),p=new He(m,new Lt({color:6190132,roughness:.95,flatShading:!0}),90),S=new He(new ye(.22,6,4),new Lt({color:16765498,roughness:.6,emissive:3811840}),1600),E=0,g=0;u(90,4e3,t-30,e+30,i-40,s+18,3,(nt,rt)=>{let B=1.3+a()*2.2;l.position.set(nt,B*.45,rt),l.rotation.set(0,a()*3,0),l.scale.set(B,B*.7,B),l.updateMatrix(),p.setMatrixAt(E++,l.matrix);for(let Z=0;Z<16&&g<1600;Z++){let ct=a()*6.283,z=a()*1.2;l.position.set(nt+Math.cos(ct)*Math.cos(z)*B,B*.45+Math.sin(z)*B*.7,rt+Math.sin(ct)*Math.cos(z)*B),l.scale.setScalar(.7+a()*.7),l.updateMatrix(),S.setMatrixAt(g++,l.matrix)}}),p.count=E,S.count=g,p.castShadow=!0,n.add(p,S);let C=new He(m,new Lt({color:7310916,roughness:1}),160),A=new He(new ye(.42,10,8),new Lt({roughness:.7}),900),_=0,T=0;u(160,6e3,t-35,e+35,i-45,s+30,1.6,(nt,rt)=>{l.position.set(nt,.2,rt),l.rotation.set(0,0,0),l.scale.set(.9,.35,.9),l.updateMatrix(),C.setMatrixAt(_++,l.matrix);for(let B=0;B<5&&T<900;B++){let Z=a()*6.283,ct=a()*.7;l.position.set(nt+Math.cos(Z)*ct,.9+a()*.6,rt+Math.sin(Z)*ct),l.scale.setScalar(.8+a()*.5),l.updateMatrix(),A.setMatrixAt(T,l.matrix),c.set(h([15182272,15906508,14258096,16173014])),A.setColorAt(T++,c)}}),C.count=_,A.count=T,n.add(C,A);let v=new un(.22,2.2,3);v.translate(0,1.1,0);let y=new He(v,new Lt({roughness:1}),2200),w=0;u(2200,14e3,t-50,e+50,i-60,s+40,1.4,(nt,rt)=>{l.position.set(nt,0,rt),l.rotation.set(.25+a()*.2,0,-.35+(a()-.5)*.3),l.scale.set(1,.6+a()*.8,1),l.updateMatrix(),y.setMatrixAt(w,l.matrix),c.set(h(r.grass)).offsetHSL(0,-.05,(a()-.4)*.12),y.setColorAt(w++,c)}),y.count=w,n.add(y);let P=new Lt({color:13615789,roughness:1}),D=new Lt({color:13217156,roughness:.95}),N=new Lt({color:9334350,roughness:.9});u(9,2e3,t-20,e+20,i-25,s+12,3.5,(nt,rt)=>{let B=4+a()*6,Z=new $(new oe(.35+a()*.25,.5+a()*.3,B,7),P);Z.rotation.set(Math.PI/2,0,a()*3),Z.position.set(nt,.45,rt),Z.castShadow=!0,n.add(Z)}),u(8,2e3,t-14,e+14,i-18,s+10,3,(nt,rt)=>{for(let B=0;B<3;B++){let Z=new $(new _n(1.1-B*.3,.2,6,20),D);Z.rotation.x=Math.PI/2,Z.position.set(nt,.2+B*.25,rt),Z.castShadow=!0,n.add(Z)}}),u(7,2e3,t-16,e+16,i-20,s+10,3.5,(nt,rt)=>{let B=new he;for(let z=0;z<4;z++){let j=new $(new _n(1,.1,6,16,Math.PI),N);j.position.x=-1.2+z*.8,j.rotation.y=Math.PI/2,B.add(j)}let Z=new $(new Ee(3,.25,2.1),N);B.add(Z);let ct=new $(new oe(.95,.95,2.6,12,1,!0,0,Math.PI),new Lt({color:4085088,transparent:!0,opacity:.45,side:Ce}));ct.rotation.z=Math.PI/2,B.add(ct),B.position.set(nt,.15,rt),B.rotation.y=a()*3,B.traverse(z=>{z.castShadow=!0}),n.add(B)});let H=new Lt({color:16777215,side:Ce,roughness:.6}),U=new Lt({color:2763306,side:Ce}),k=[];for(let nt=0;nt<6;nt++){let rt=new he,B=new $(new ye(.55,10,8),H);B.scale.set(2.2,.8,.8),rt.add(B);let Z=new ln;Z.moveTo(.5,0),Z.quadraticCurveTo(.6,1.4,-.3,3.1),Z.lineTo(-.7,2.6),Z.quadraticCurveTo(-.4,1.2,-.6,0),Z.lineTo(.5,0);let ct=new ts(Z,6),z=dt=>{let Ct=new he,Q=new $(ct,H);Q.rotation.x=-Math.PI/2,Q.scale.set(1,dt,1),Ct.add(Q);let ht=new $(new yn(.35,6),U);return ht.rotation.x=-Math.PI/2,ht.position.set(-.5,.02,dt*2.8),Ct.add(ht),rt.add(Ct),Ct},j=z(1),ft=z(-1);rt.traverse(dt=>{dt.castShadow=!0}),n.add(rt),rt.scale.setScalar(.8),k.push({g:rt,L:j,R:ft,cx:a()<.5?t-25:e+25,cy:(i+s)/2+(a()-.5)*80,rad:18+a()*22,h:30+a()*16,sp:.12+a()*.1,ph:a()*6})}d.push(nt=>{for(let rt of k){let B=nt*rt.sp+rt.ph,Z=rt.cx+Math.cos(B)*rt.rad,ct=rt.cy+Math.sin(B)*rt.rad*.7;rt.g.position.set(Z,rt.h+Math.sin(B*2)*2,ct),rt.g.rotation.y=-B-Math.PI/2;let z=Math.sin(nt*5+rt.ph)*.45+.1;rt.L.rotation.x=-z,rt.R.rotation.x=z}});let F=document.createElement("canvas");F.width=F.height=256;let G=F.getContext("2d");G.fillStyle="#000",G.fillRect(0,0,256,256);for(let nt=0;nt<6;nt++){let rt=a()*256,B=a()*256,Z=40+a()*50,ct=G.createRadialGradient(rt,B,0,rt,B,Z);ct.addColorStop(0,"rgba(255,255,255,.85)"),ct.addColorStop(1,"rgba(255,255,255,0)"),G.fillStyle=ct,G.beginPath(),G.arc(rt,B,Z,0,7),G.fill()}let q=new Qe(F);q.wrapS=q.wrapT=Ge,q.repeat.set(2,2);let et=new $(new we(600,700),new Se({color:662048,alphaMap:q,transparent:!0,opacity:.16,depthWrite:!1}));return et.rotation.x=-Math.PI/2,et.position.set((t+e)/2,.08,(i+s)/2),et.renderOrder=2,n.add(et),d.push(nt=>{q.offset.set(nt*.014,nt*.006)}),{update:nt=>{for(let rt of d)rt(nt)}}}var Fh=4242,Ft=()=>(Fh=Fh*16807%2147483647,Fh/2147483647),$n=(n,t,e)=>{let i=document.createElement("canvas");i.width=n,i.height=t,e(i.getContext("2d"),n,t);let s=new Qe(i);return s.colorSpace=Pe,s.anisotropy=8,s},De=(n,t)=>new at(n,t),Ht=n=>new Lt(n),te=n=>(n.castShadow=!0,n.receiveShadow=!0,n),n_=$n(128,128,(n,t)=>{let e=n.createRadialGradient(64,64,4,64,64,62);e.addColorStop(0,"rgba(0,0,0,.55)"),e.addColorStop(.55,"rgba(0,0,0,.28)"),e.addColorStop(1,"rgba(0,0,0,0)"),n.fillStyle=e,n.fillRect(0,0,t,t)}),Ar=$n(128,256,(n,t,e)=>{n.fillStyle="#6b4a2c",n.fillRect(0,0,t,e);for(let i=0;i<70;i++){n.strokeStyle=`rgba(${30+Ft()*30},${18+Ft()*16},8,${.35+Ft()*.4})`,n.lineWidth=2+Ft()*4;let s=Ft()*t;n.beginPath(),n.moveTo(s,0),n.bezierCurveTo(s+Ft()*10-5,e*.3,s+Ft()*10-5,e*.7,s+Ft()*8-4,e),n.stroke()}for(let i=0;i<40;i++)n.fillStyle="rgba(160,120,80,.25)",n.fillRect(Ft()*t,Ft()*e,3,8)});Ar.wrapS=Ar.wrapT=Ge;var Oh=$n(128,128,(n,t)=>{n.fillStyle="#dcb47c",n.fillRect(0,0,t,t);for(let e=5;e<64;e+=5+Ft()*3)n.strokeStyle=`rgba(130,85,40,${.35+Ft()*.3})`,n.lineWidth=1.5+Ft(),n.beginPath(),n.arc(64+Ft()*2,64+Ft()*2,e,0,7),n.stroke();n.strokeStyle="rgba(90,55,25,.6)",n.lineWidth=6,n.beginPath(),n.arc(64,64,62,0,7),n.stroke()}),Bh=$n(256,256,(n,t,e)=>{n.fillStyle="#ddb455",n.fillRect(0,0,t,e);for(let i=0;i<1600;i++){let s=Ft()*t,r=Ft()*e,a=(Ft()-.5)*.7;n.strokeStyle=`rgba(${170+Ft()*80},${120+Ft()*70},${30+Ft()*40},${.5+Ft()*.4})`,n.lineWidth=.8+Ft()*1.4,n.beginPath(),n.moveTo(s,r),n.lineTo(s+Math.cos(a)*26,r+Math.sin(a)*26),n.stroke()}});Bh.wrapS=Bh.wrapT=Ge;var Hh=(n,t)=>{let e=$n(256,256,(i,s,r)=>{i.fillStyle=n,i.fillRect(0,0,s,r);for(let a=0;a<r;a+=32){i.fillStyle=t,i.fillRect(0,a,s,3);for(let o=0;o<14;o++){i.strokeStyle="rgba(60,40,20,.18)",i.lineWidth=1;let l=a+5+Ft()*24;i.beginPath(),i.moveTo(0,l),i.bezierCurveTo(s*.3,l+Ft()*4-2,s*.7,l+Ft()*4-2,s,l),i.stroke()}i.fillStyle="rgba(40,30,20,.55)",i.beginPath(),i.arc(14,a+16,2.2,0,7),i.arc(s-14,a+16,2.2,0,7),i.fill()}});return e.wrapS=e.wrapT=Ge,e},Lo=$n(64,64,(n,t,e)=>{n.fillStyle="#cdb38a",n.fillRect(0,0,t,e),n.strokeStyle="rgba(120,90,50,.55)",n.lineWidth=6;for(let i=-64;i<128;i+=14)n.beginPath(),n.moveTo(i,0),n.lineTo(i+40,e),n.stroke()});Lo.wrapS=Lo.wrapT=Ge;function Sf({scene:n,hAt:t,theme:e,cellAt:i}){let s=e==="bluffs",r=[],a=_=>_===1||_===4||_===5||_===6;function o(_,T,v,y=96,w=a){_.updateMatrixWorld(!0);let P=document.createElement("canvas"),D=Math.max(8,Math.round(y*Math.min(1,T/Math.max(T,v))*1.5)),N=Math.max(8,Math.round(y*Math.min(1,v/Math.max(T,v))*1.5));P.width=D,P.height=N;let H=P.getContext("2d"),U=H.createImageData(D,N),k=new O;for(let G=0;G<N;G++)for(let q=0;q<D;q++){k.set(((q+.5)/D-.5)*T,(.5-(G+.5)/N)*v,0).applyMatrix4(_.matrixWorld);let et=(G*D+q)*4,nt=w(i(k.x,k.z))?255:0;U.data[et]=U.data[et+1]=U.data[et+2]=nt,U.data[et+3]=255}H.putImageData(U,0,0);let F=new Qe(P);return _.material.alphaMap=F,_.material.transparent=!0,_.material.needsUpdate=!0,_}let l=(_,T,v,y=v,w=0)=>{let P=new $(new we(v*2.4,y*2.4),new Se({map:n_,transparent:!0,depthWrite:!1,opacity:.85}));return P.rotation.x=-Math.PI/2,P.rotation.z=-w,P.position.set(_,t(_,T)+.07,T),P.renderOrder=1,n.add(P),P};function c(_,T,v,y){let w=Math.min(3,256/Math.max(v,y)),P=Math.max(8,Math.round(v*w)),D=Math.max(8,Math.round(y*w)),N=document.createElement("canvas");N.width=P,N.height=D;let H=N.getContext("2d"),U=H.createImageData(P,D),k=1.8,F=.3,G=[];for(let nt=-k;nt<=k;nt+=F)for(let rt=-k;rt<=k;rt+=F){let B=Math.hypot(rt,nt);B<=k&&B>0&&G.push([rt,nt,B])}G.sort((nt,rt)=>nt[2]-rt[2]);for(let nt=0;nt<D;nt++)for(let rt=0;rt<P;rt++){let B=_+(rt+.5)/w,Z=T+(nt+.5)/w,ct=(nt*P+rt)*4;if(i(B,Z)!==5){U.data[ct+3]=0;continue}let z=k+1;for(let[j,ft,dt]of G)if(i(B+j,Z+ft)!==5){z=dt;break}if(z<.55)U.data[ct]=U.data[ct+1]=U.data[ct+2]=248,U.data[ct+3]=235;else if(z<=k){let j=1-(z-.55)/(k-.55);U.data[ct]=4,U.data[ct+1]=32,U.data[ct+2]=48,U.data[ct+3]=Math.round(150*j)}else U.data[ct+3]=0}H.putImageData(U,0,0);let q=new Qe(N);q.colorSpace=Pe;let et=new $(new we(v,y),new Se({map:q,transparent:!0,depthWrite:!1}));return et.rotation.x=-Math.PI/2,et.position.set(_+v/2,.03,T+y/2),et.renderOrder=2,n.add(et),et}let h=new un(.18,.9,4);h.translate(0,.45,0);let d=Ht({color:s?10135648:5213998,roughness:1}),u=(_,T,v)=>{for(let y=0;y<v;y++){let w=y/v*6.283+Ft()*.4,P=T*(.95+Ft()*.25),D=new $(h,d);D.position.set(Math.cos(w)*P,0,Math.sin(w)*P),D.rotation.set((Ft()-.5)*.6,0,(Ft()-.5)*.6),D.scale.setScalar(.7+Ft()*.7),_.add(D)}};function f(_){let T=new he,v=_.r;if(s){let y=$n(64,256,(U,k,F)=>{for(let G=0;G<6;G++)U.fillStyle=G%2?"#f4f1ea":"#d8352b",U.fillRect(0,G*F/6,k,F/6)}),w=te(new $(new ji([De(.001,.1),De(.75*v,.25),De(1.15*v,.9),De(1.2*v,1.7),De(1*v,2.6),De(.55*v,3.2),De(.001,3.35)],32),new ri({map:y,roughness:.35,clearcoat:.7})));T.add(w);let P=new he;for(let U=0;U<4;U++){let k=new $(new oe(.06,.06,1.6,6),Ht({color:3817284,metalness:.6,roughness:.4}));k.position.set(Math.cos(U*1.571)*.35*v,4,Math.sin(U*1.571)*.35*v),P.add(k)}let D=new $(new ye(.28*v,12,8),Ht({color:16769658,emissive:16761402,emissiveIntensity:1.2}));D.position.y=4,P.add(D);let N=new $(new un(.45*v,.5,12),Ht({color:3817284,metalness:.6,roughness:.4}));N.position.y=4.9,P.add(N),T.add(P);let H=new $(new _n(1.18*v,.12,8,32),Ht({map:Lo,roughness:.9}));H.rotation.x=Math.PI/2,H.position.y=1.3,T.add(H),r.push(U=>{T.rotation.z=Math.sin(U*1.7+_.x)*.05,T.rotation.x=Math.cos(U*1.3+_.y)*.05,D.material.emissiveIntensity=.8+.6*Math.max(0,Math.sin(U*3+_.x))})}else{let y=te(new $(new ji([De(.72*v,0),De(.74*v,.15),De(.62*v,.6),De(.55*v,1.4),De(.58*v,2.1),De(.42*v,2.45)].map(k=>k),24),Ht({color:16050898,roughness:.75})));T.add(y);let w=te(new $(new ji([De(.56*v,1.8),De(.86*v,1.55),De(.82*v,1.5)],24),Ht({color:15720640,roughness:.8,side:Ce})));T.add(w);let P=[De(.001,3.6),De(.5*v,3.5),De(.9*v,3.2),De(1.15*v,2.8),De(1.26*v,2.4),De(1.22*v,2.22),De(1.05*v,2.2)],D=te(new $(new ji(P.slice().reverse(),32),new ri({color:14234666,roughness:.35,clearcoat:.6,clearcoatRoughness:.3})));T.add(D);let N=new $(new gr(.5*v,1.2*v,32,1),Ht({map:$n(128,128,(k,F)=>{k.fillStyle="#efe3c8",k.fillRect(0,0,F,F),k.strokeStyle="rgba(150,120,80,.5)",k.lineWidth=1.5;for(let G=0;G<64;G++){let q=G/64*6.283;k.beginPath(),k.moveTo(64+Math.cos(q)*20,64+Math.sin(q)*20),k.lineTo(64+Math.cos(q)*64,64+Math.sin(q)*64),k.stroke()}}),side:Ce,roughness:.9}));N.rotation.x=Math.PI/2,N.position.y=2.21,T.add(N);let H=Ht({color:16775920,roughness:.6}),U=new ye(1,12,8);for(let k=0;k<11;k++){let F=.12+Ft()*.72,G=Ft()*6.283,q=Math.min(P.length-2,Math.floor(F*(P.length-1))),et=F*(P.length-1)-q,nt=P[q].x+(P[q+1].x-P[q].x)*et,rt=P[q].y+(P[q+1].y-P[q].y)*et,B=new $(U,H),Z=v*(.12+Ft()*.1);B.scale.set(Z,Z*.3,Z),B.position.set(Math.cos(G)*nt,rt,Math.sin(G)*nt),B.lookAt(Math.cos(G)*nt*2,rt+(3.6-rt)*.9+1,Math.sin(G)*nt*2),B.rotateX(Math.PI/2),T.add(B)}}return T.position.set(_.x,t(_.x,_.y),_.y),n.add(T),l(_.x,_.y,v*1.25),T}function x(_){let T=new he,v=new he,y=new he;if(s){let w=Ht({color:6964264,roughness:.5,metalness:.05}),P=Ht({color:13214282,metalness:.85,roughness:.3}),D=te(new $(new oe(1.4,1.7,2.4,16),Ht({color:9211786,roughness:.9})));D.position.y=1.2,T.add(D);let N=te(new $(new oe(1,1,.9,16),P));N.position.y=2.7,y.add(N);let H=te(new $(new _n(3,.32,10,36),w));H.rotation.x=Math.PI/2,H.position.y=2.75,y.add(H);for(let U=0;U<8;U++){let k=U*Math.PI/4,F=te(new $(new oe(.16,.16,4.4,8),w));F.rotation.z=Math.PI/2,F.rotation.y=-k,F.position.set(Math.cos(k)*2.2,2.75,Math.sin(k)*2.2),y.add(F);let G=te(new $(new ye(.32,10,8),w));G.position.set(Math.cos(k)*4.35,2.75,Math.sin(k)*4.35),y.add(G)}T.add(y);for(let U=0;U<_.arms;U++){let k=new he;k.rotation.y=-U*2*Math.PI/_.arms;let F=te(new $(new Ee(_.L-1.3,_.r*2,_.r*2),Ht({map:Hh("#7b5a3a","rgba(30,20,10,.6)"),roughness:.8})));F.position.set(1.3+(_.L-1.3)/2,1,0),k.add(F);let G=te(new $(new Ee(.4,_.r*2.3,_.r*2.3),P));G.position.set(_.L-.2,1,0),k.add(G),v.add(k)}}else{let w=te(new $(new oe(.75,1,5,14),Ht({color:5212716,roughness:.7})));w.position.y=2.5,T.add(w);let P=new ln;P.moveTo(0,0),P.quadraticCurveTo(1.6,.9,3.4,0),P.quadraticCurveTo(1.6,-.9,0,0);for(let[G,q]of[[.6,2.6],[3.6,3.4]]){let et=te(new $(new ts(P,8),Ht({color:5937714,roughness:.7,side:Ce})));et.position.y=q,et.rotation.set(-.5,G,.35),T.add(et)}let D=$n(256,256,(G,q)=>{G.fillStyle="#4a2a10",G.fillRect(0,0,q,q);for(let et=0;et<520;et++){let nt=et*2.39996,rt=Math.sqrt(et)*5.4;G.fillStyle=et%3?"#6b3e16":"#2c1606",G.beginPath(),G.arc(128+Math.cos(nt)*rt,128+Math.sin(nt)*rt,3.2,0,7),G.fill()}}),N=te(new $(new oe(1.7,1.8,.7,28),[Ht({color:5911574,roughness:1}),Ht({map:D,roughness:.9}),Ht({color:3809804})]));y.add(N);let H=new ln;H.moveTo(0,-.42),H.quadraticCurveTo(1.5,-.55,2.4,0),H.quadraticCurveTo(1.5,.55,0,.42);let U=new ts(H,6),k=Ht({color:16761375,roughness:.55,side:Ce,emissive:3810304});for(let G=0;G<22;G++){let q=te(new $(U,k)),et=G/22*6.283+G%2*.14;q.rotation.order="YXZ",q.rotation.y=-et,q.rotation.x=-Math.PI/2+(G%2?.28:.12),q.position.set(Math.cos(et)*1.45,G%2?.1:.2,Math.sin(et)*1.45),q.scale.setScalar(G%2?.9:1),y.add(q)}y.position.y=5.3,y.rotation.x=.35,T.add(y);let F=te(new $(new oe(1.6,1.7,2.2,18),Ht({map:Ar,roughness:.95})));F.position.y=1.1,T.add(F);for(let G=0;G<_.arms;G++){let q=new he;q.rotation.y=-G*2*Math.PI/_.arms;let et=te(new $(new oe(_.r,_.r*1.05,_.L-1.2,12),[Ht({map:Ar,roughness:.95}),Ht({map:Oh}),Ht({map:Oh})]));et.rotation.z=Math.PI/2,et.position.set(1.2+(_.L-1.2)/2,1,0),q.add(et);let nt=new $(new oe(_.r*1.12,_.r*1.12,.35,12),Ht({color:5593180,metalness:.7,roughness:.35}));nt.rotation.z=Math.PI/2,nt.position.set(1.9,1,0),q.add(nt),v.add(q)}}return T.add(v),T.position.set(_.x,t(_.x,_.y),_.y),n.add(T),l(_.x,_.y,2.2),{arms:v,head:y,spinHead:!s}}function M(_,T){let v=new he,y=_.hw*2,w=_.hh*2,P=3.2;if(!s&&T!=="crate"){let N=new ln,H=-y/2+.35,U=y/2-.35,k=-w/2+.35,F=w/2-.35,G=Math.min(.5,(U-H)/3,(F-k)/3);N.moveTo(H+G,k),N.lineTo(U-G,k),N.quadraticCurveTo(U,k,U,k+G),N.lineTo(U,F-G),N.quadraticCurveTo(U,F,U-G,F),N.lineTo(H+G,F),N.quadraticCurveTo(H,F,H,F-G),N.lineTo(H,k+G),N.quadraticCurveTo(H,k,H+G,k);let q=new si(N,{depth:P-2*.35,bevelEnabled:!0,bevelThickness:.35,bevelSize:.35,bevelSegments:3});q.rotateX(-Math.PI/2),q.translate(0,.35,0);let et=Bh.clone();et.needsUpdate=!0,et.repeat.set(.22,.22),et.wrapS=et.wrapT=Ge,v.add(te(new $(q,Ht({map:et,roughness:1}))));let nt=Ht({color:7027996,roughness:.9}),rt=y>=w;for(let B of[-.28,.28]){let Z=te(new $(new Ee(rt?.28:y+.12,P+.1,rt?w+.12:.28),nt));Z.position.set(rt?B*y:0,P/2,rt?0:B*w),v.add(Z)}for(let B=0;B<10;B++){let Z=new $(new oe(.04,.04,1+Ft(),4),Ht({color:15255146}));Z.position.set((Ft()-.5)*y*.9,P+.05,(Ft()-.5)*w*.9),Z.rotation.set(Math.PI/2+(Ft()-.5),Ft()*3,0),v.add(Z)}}else{let D=Ht({map:Hh("#9a7a58","rgba(40,28,18,.7)"),roughness:.85}),N=Ht({color:6178352,roughness:.9}),H=new $(new Ee(y-.6,P-.4,w-.6),Ht({color:2893344,roughness:1}));H.position.y=P/2,v.add(H);for(let F of[-1,1])for(let G of[-1,1]){let q=te(new $(new Ee(.5,P,.5),N));q.position.set(F*(y/2-.25),P/2,G*(w/2-.25)),v.add(q)}for(let F=.4;F<P;F+=.75){for(let G of[-1,1]){let q=te(new $(new Ee(y,.42,.18),D));q.position.set(0,F,G*(w/2-.09)),v.add(q)}for(let G of[-1,1]){let q=te(new $(new Ee(.18,.42,w),D));q.position.set(G*(y/2-.09),F,0),v.add(q)}}for(let F=-y/2+.5;F<y/2;F+=.9){let G=te(new $(new Ee(.45,.16,w),D));G.position.set(F,P,0),v.add(G)}let U=te(new $(new _n(Math.min(y,w)*.22,.22,8,24),Ht({map:Lo,roughness:.9})));U.rotation.x=Math.PI/2,U.position.set(y*.15,P+.25,0),v.add(U);let k=te(new $(new ye(.55,14,10),Ht({color:15901242,roughness:.4})));k.position.set(-y*.2,P+.5,w*.1),v.add(k)}return v.rotation.y=-_.a,v.position.set(_.x,t(_.x,_.y),_.y),n.add(v),l(_.x,_.y,_.hw*1.15,_.hh*1.15+.6,_.a),v}function m(_){let T=new he;if(s){let v=te(new $(new oe(_.r*.9,_.r,3,18),Ht({color:10461852,roughness:.85})));v.position.y=1.5,T.add(v);let y=te(new $(new ye(_.r*.9,18,8,0,6.283,0,Math.PI/2),Ht({color:11843505,roughness:.8})));y.position.y=3,y.scale.y=.4,T.add(y)}else{T.add(te(new $(new oe(_.r,_.r*1.12,3.4,18,1),[Ht({map:Ar,roughness:1}),Ht({map:Oh,roughness:.9}),Ht({color:3811348})]))),T.children[0].position.y=1.7;for(let y=0;y<4;y++){let w=y*1.571+Ft()*.5,P=te(new $(new un(.55,2.4,8),Ht({map:Ar,roughness:1})));P.rotation.z=Math.PI/2-.5,P.rotation.y=-w,P.position.set(Math.cos(w)*_.r*.95,.35,Math.sin(w)*_.r*.95),T.add(P)}let v=new $(new ye(_.r*.45,10,6),Ht({color:6262586,roughness:1}));v.scale.set(1,.3,1),v.position.set(-_.r*.35,3.42,_.r*.2),T.add(v)}return T.position.set(_.x,t(_.x,_.y),_.y),n.add(T),l(_.x,_.y,_.r*1.3),T}function p(){let _=new he,T=new he;_.add(T);let v=[];if(s){let y=Ht({color:14833454,roughness:.45}),w=Ht({color:1710618,roughness:.3}),P=te(new $(new ye(1.4,20,12),y));P.scale.set(1.25,.55,1),P.position.y=1,T.add(P);for(let D of[-.45,.45]){let N=new $(new oe(.07,.07,.6,6),y);N.position.set(.3,1.6,D*.6),T.add(N);let H=new $(new ye(.16,8,6),w);H.position.set(.3,1.95,D*.6),T.add(H)}for(let D of[-1,1]){let N=te(new $(new oe(.16,.2,1.3,8),y));N.rotation.x=D*1,N.position.set(1.4,1,D*1.1),T.add(N);let H=te(new $(new ye(.45,12,8),y));H.scale.set(1.3,.8,.8),H.position.set(1.7,1.15,D*1.65),T.add(H)}for(let D=0;D<6;D++){let N=D<3?-1:1,H=D%3,U=new $(new oe(.08,.06,1.5,5),y);U.rotation.x=N*1.1,U.position.set(-.6+H*.6,.55,N*1.25),T.add(U),v.push(U)}}else{let y=Ht({color:8018490,roughness:1}),w=Ht({color:15257512,roughness:.9}),P=Ht({color:1118481,roughness:.3}),D=te(new $(new ye(1.5,20,14),y));D.scale.set(1.25,.85,1),D.position.y=1.25,T.add(D);let N=new un(.13,.75,5);N.translate(0,.37,0);let H=new He(N,Ht({color:4863264,roughness:1}),120),U=new Oe,k=0;for(let q=0;q<160&&k<120;q++){let et=Ft(),nt=Ft()*.85,rt=et*6.283,B=nt*Math.PI/2,Z=Math.cos(B)*Math.cos(rt),ct=Math.sin(B),z=Math.cos(B)*Math.sin(rt);Z>.55||(U.position.set(Z*1.5*1.25,1.25+ct*1.5*.85,z*1.5),U.lookAt(U.position.x+Z-.6,U.position.y+ct+.2,U.position.z+z),U.rotateX(Math.PI/2),U.updateMatrix(),H.setMatrixAt(k++,U.matrix))}H.count=k,H.castShadow=!0,T.add(H);let F=te(new $(new un(.62,1.4,14),w));F.rotation.z=-Math.PI/2,F.position.set(2.1,1.05,0),T.add(F);let G=new $(new ye(.18,10,8),P);G.position.set(2.8,1.05,0),T.add(G);for(let q of[-.38,.38]){let et=new $(new ye(.12,8,6),P);et.position.set(1.85,1.45,q),T.add(et)}for(let[q,et]of[[.8,.7],[.8,-.7],[-.8,.7],[-.8,-.7]]){let nt=new $(new oe(.16,.16,.6,6),w);nt.position.set(q,.3,et),T.add(nt),v.push(nt)}}return n.add(_),{g:_,update(y,w,P,D,N){_.position.set(w,t(w,P),P),s?(_.rotation.y=0,T.position.y=Math.abs(Math.sin(y*14+N))*.12,v.forEach((H,U)=>{H.rotation.z=Math.sin(y*16+U)*.35})):(_.rotation.y=D>0?0:Math.PI,T.position.y=Math.abs(Math.sin(y*9+N))*.18,v.forEach((H,U)=>{H.rotation.z=Math.sin(y*12+U*1.7)*.5}))}}}function S(_,T,v,y){let w=new he,P=Ht({color:new Ot(v),roughness:.35,metalness:.35}),D=new Se({color:460037}),N=te(new $(new oe(2.6,2.6,4.4,28,1,!0),P));N.rotation.x=Math.PI/2,N.position.set(0,2,y?-2.4:0),w.add(N);let H=te(new $(new _n(2.7,.5,12,32),P));H.position.set(0,2,y?-.25:2.15),w.add(H);let U=Ht({color:14277081,metalness:.9,roughness:.25});for(let q=0;q<8;q++){let et=q*.785,nt=new $(new ye(.16,8,6),U);nt.position.set(Math.cos(et)*2.7,2+Math.sin(et)*2.7,(y?-.25:2.15)+.48),w.add(nt)}let k=new $(new yn(2.25,24),D);k.position.set(0,2,y?-.3:2.1),y||(k.rotation.y=0),w.add(k);let F=new $(new yn(2.4,24),D);F.rotation.x=-Math.PI/2,F.position.set(0,.06,0),w.add(F);let G=new $(new gr(2.4,2.9,24),P);return G.rotation.x=-Math.PI/2,G.position.set(0,.07,0),w.add(G),w.position.set(_,t(_,T),T),n.add(w),l(_,T-(y?2:0),3.2),w}function E(_){let T=Math.hypot(_.x2-_.x1,_.y2-_.y1),v=Math.max(1,Math.ceil(T/6)),y=Ht({color:7230006,roughness:.9}),w=[];for(let D=0;D<=v;D++){let N=_.x1+(_.x2-_.x1)*D/v,H=_.y1+(_.y2-_.y1)*D/v,U=t(N,H),k=te(new $(new oe(.32,.38,2.6,10),y));k.position.set(N,U+1.3,H),n.add(k);let F=new $(new ye(.36,10,6),y);if(F.position.set(N,U+2.62,H),n.add(F),D){let G=(w[w.length-1].x+N)/2,q=(w[w.length-1].z+H)/2;w.push(new O(G,U+1.7,q))}w.push(new O(N,U+2.2,H))}let P=te(new $(new mo(new mr(w),w.length*6,.2,8,!1),Ht({map:Lo,roughness:.9})));n.add(P),l((_.x1+_.x2)/2,(_.y1+_.y2)/2,T/2.2,.8,Math.atan2(_.y2-_.y1,_.x2-_.x1))}function g(_){let T=$n(128,128,(P,D,N)=>{P.clearRect(0,0,D,N);for(let H=0;H<26;H++){let U=Ft()*N,k=Ft()*D,F=18+Ft()*40;P.strokeStyle=`rgba(255,255,255,${.35+Ft()*.4})`,P.lineWidth=1.5+Ft()*2.5,P.lineCap="round",P.beginPath(),P.moveTo(k,U),P.quadraticCurveTo(k+F/2,U-3,k+F,U),P.stroke()}P.fillStyle="rgba(255,255,255,.55)";for(let H of[30,94])P.beginPath(),P.moveTo(H,50),P.lineTo(H+16,64),P.lineTo(H,78),P.lineTo(H+6,64),P.closePath(),P.fill()});T.wrapS=T.wrapT=Ge,T.repeat.set(_.hw*2/14,_.hh*2/14);let v=t(_.x,_.y),y=new $(new we(_.hw*2,_.hh*2),new Lt({color:3121087,transparent:!0,opacity:.45,roughness:.15,metalness:.1,depthWrite:!1}));y.rotation.x=-Math.PI/2,y.rotation.z=-_.a,y.position.set(_.x,v+.09,_.y),y.renderOrder=1,n.add(y),o(y,_.hw*2,_.hh*2);let w=new $(new we(_.hw*2,_.hh*2),new Se({map:T,transparent:!0,depthWrite:!1}));w.rotation.x=-Math.PI/2,w.rotation.z=-_.a,w.position.set(_.x,v+.11,_.y),w.renderOrder=2,n.add(w),o(w,_.hw*2,_.hh*2),r.push(P=>{T.offset.x=-P*.9*(_.f/200),y.material.opacity=.4+.08*Math.sin(P*1.6)})}function C(_){let T=new he,v=Ht({map:Hh("#a08a6e","rgba(50,40,30,.6)"),roughness:.9});for(let y=-_.hw+.55;y<_.hw;y+=1.15)for(let w=-_.hh+.5;w<_.hh;w+=1){let P=_.x+y*_.c-w*_.s,D=_.y+y*_.s+w*_.c;if(!a(i(P,D)))continue;let N=new $(new Ee(1,.14,1.02),v);N.position.set(y,.08,w),N.receiveShadow=!0,T.add(N)}T.rotation.y=-_.a,T.position.set(_.x,t(_.x,_.y),_.y),n.add(T)}function A(_,T,v){let y=new he,w=v?4.4:3.8,P=Ht({color:9067830,roughness:1}),D=new Se({color:328450}),N=te(new $(new ye(w,28,14,0,Math.PI*2,0,Math.PI/2),Ht({map:$n(128,128,(F,G)=>{F.fillStyle="#8a5d36",F.fillRect(0,0,G,G);for(let q=0;q<500;q++)F.fillStyle=Ft()<.5?"rgba(60,35,15,.35)":"rgba(180,130,80,.3)",F.fillRect(Ft()*G,Ft()*G,2+Ft()*3,2+Ft()*3)}),roughness:1})));N.scale.y=.55,N.position.z=.9-w,y.add(N);let H=te(new $(new _n(2,.55,10,20,Math.PI),P));H.position.set(0,0,.9),y.add(H);let U=new $(new yn(2,24,0,Math.PI),D);U.position.set(0,.02,.85),y.add(U);let k=new $(new yn(2.1,24),D);k.rotation.x=-Math.PI/2,k.scale.y=.55,k.position.set(0,.06,1.4),y.add(k);for(let F=0;F<7;F++){let G=te(new $(new Cs(.3+Ft()*.3,0),Ht({color:10130570,roughness:.9,flatShading:!0}))),q=Ft()*Math.PI-Math.PI;G.position.set(Math.cos(q)*(w*.9),.15,Math.sin(q)*w*.5+.8),y.add(G)}for(let F=0;F<12;F++){let G=new $(h,d),q=Ft()*6.283;G.position.set(Math.cos(q)*w*.6,w*.35*(.3+Ft()*.5),Math.sin(q)*w*.5+.9-w),G.scale.setScalar(.8+Ft()*.6),y.add(G)}return y.position.set(_,t(_,T),T-.4),n.add(y),l(_,T-1.2,w*1.1,w*.8),y}return{waterEdge:c,clip:o,burrow:A,bouncer:f,spinner:x,block:M,stump:m,critter:p,pipeMouth:S,ropeRail:E,current:g,boardwalk:C,shadow:l,update:_=>{for(let T of r)T(_)}}}var Rr={rookie:{key:"rookie",name:"Rookie",lvl:"Newbie",col:"#5aa9d6",face:"\u{1F60A}",step:15,pstep:.12,risk:0,aim:.15,pow:.24,duff:.15,think:[.9,1.5],bonus:5,emote:{good:"\u{1F605}",bad:"\u{1F62C}",you:"\u{1F62E}"}},ace:{key:"ace",name:"Ace",lvl:"Pro",col:"#e0a62a",face:"\u{1F60E}",step:6,pstep:.075,risk:20,aim:.045,pow:.07,duff:0,think:[.7,1.2],bonus:10,emote:{good:"\u{1F60E}",bad:"\u{1F610}",you:"\u{1F44D}"}},oracle:{key:"oracle",name:"The Oracle",lvl:"God",col:"#9a55e0",face:"\u{1F52E}",step:3,pstep:.05,risk:30,aim:.008,pow:.015,duff:0,think:[.5,.9],refine:!0,bonus:25,emote:{good:"\u{1F60F}",bad:"\u{1F928}",you:"\u{1F44F}"}}};function wf(n,t){let e=n.grid,i=Uint8Array.from(atob(e.b64),u=>u.charCodeAt(0)),s=e.w,r=e.h,a=(u,f)=>{let x=Math.floor((u-e.x0)*e.res),M=Math.floor((f-e.y0)*e.res);return x<0||M<0||x>=s||M>=r?-1:M*s+x},o=null;function l(){let u=S=>S===1||S===4||S===6;o=new Float64Array(s*r).fill(1e9);let f=[],x=(S,E)=>{f.push([S,E]);let g=f.length-1;for(;g;){let C=g-1>>1;if(f[C][0]<=f[g][0])break;[f[C],f[g]]=[f[g],f[C]],g=C}},M=()=>{let S=f[0],E=f.pop();if(f.length){f[0]=E;let g=0;for(;;){let C=2*g+1,A=C+1,_=g;if(C<f.length&&f[C][0]<f[_][0]&&(_=C),A<f.length&&f[A][0]<f[_][0]&&(_=A),_===g)break;[f[_],f[g]]=[f[g],f[_]],g=_}}return S},m=a(n.cup[0],n.cup[1]);o[m]=0,x(0,m);let p=[[1,0,1],[-1,0,1],[0,1,1],[0,-1,1],[1,1,1.414],[1,-1,1.414],[-1,1,1.414],[-1,-1,1.414]];for(;f.length;){let[S,E]=M();if(S>o[E])continue;let g=E%s,C=E/s|0;for(let[A,_,T]of p){let v=g+A,y=C+_;if(v<0||y<0||v>=s||y>=r)continue;let w=y*s+v;if(!u(i[w]))continue;let P=S+T/e.res;P<o[w]&&(o[w]=P,x(P,w))}}}let c=(u,f)=>{o||l();let x=a(u,f);return x<0?1e9:o[x]};async function h(u,f,x,M,m=6,p=null){o||l();let S=c(u,f)+45,E=w=>w.sunk?-1:w.penalty?S:c(w.x,w.y),g=[],C=Math.atan2(n.cup[1]-f,n.cup[0]-u)*180/Math.PI,A=[];for(let w=0;w<360;w+=M.step)A.push(w+C%M.step);if(M.refine)for(let w=-6;w<=6;w++)A.push(C+w*.75);let _=[];for(let w of A)for(let P=.08;P<=1.0001;P+=M.pstep)_.push([w,P]);let T=0,v=()=>{let w=performance.now();for(;T<_.length&&performance.now()-w<m;){let[P,D]=_[T++],N=Math.cos(P*Math.PI/180),H=Math.sin(P*Math.PI/180);g.push({a:P,dx:N,dy:H,pw:D,v:E(t(u,f,N,H,D,x,p))})}return T>=_.length};for(;!v();)await new Promise(w=>setTimeout(w,0));g.sort((w,P)=>w.v-P.v);let y=g[0];if(M.risk){let w=1e9,P=g.slice(0,M.risk),D=0;for(let N of P){let H=N.v,U=1,k=N.a*Math.PI/180,F=M.key==="oracle"?.5:1;for(let[q,et]of[[-.06*F,0],[.06*F,0],[0,-.07*F],[0,.07*F]]){let nt=t(u,f,Math.cos(k+q),Math.sin(k+q),Math.min(1,N.pw*(1+et)),x,p);H+=E(nt),U++}let G=H/U;G<w&&(w=G,y=N),++D%6===0&&await new Promise(q=>setTimeout(q,0))}}if(M.refine&&y.v>-1)for(let w=-2;w<=2;w+=.5)for(let P=-.04;P<=.0401;P+=.02){let D=y.a+w,N=Math.max(.06,Math.min(1,y.pw+P)),H=Math.cos(D*Math.PI/180),U=Math.sin(D*Math.PI/180),k=E(t(u,f,H,U,N,x,p));k<y.v&&(y={a:D,dx:H,dy:U,pw:N,v:k})}return y}function d(u,f,x=Math.random){let M=()=>{let S=0;for(let E=0;E<6;E++)S+=x();return S-3},m=Math.atan2(u.dy,u.dx)+M()*f.aim,p=u.pw*(1+M()*f.pow);return f.duff&&x()<f.duff&&(p*=.55),{dx:Math.cos(m),dy:Math.sin(m),pw:Math.max(.06,Math.min(1,p))}}return{plan:h,execute:d,geo:c}}var Do=(n,t)=>n.extra.some(e=>e.t===t),Jl=[{id:"mill",text:"Putt through the windmill",ok:n=>n.buildings.some(t=>t.door&&t.kind!=="barn"),done:n=>!!n.all.sail},{id:"barn",text:"Slip through the barn doors",ok:n=>n.buildings.some(t=>t.kind==="barn"),done:n=>!!n.all.barn},{id:"jump",text:"Fly off the jump ramp",ok:n=>Do(n,"kicker"),done:n=>!!n.all.jump},{id:"pipe",text:"Take a tunnel shortcut",ok:n=>n.pipes&&n.pipes.length||n.portals.length===2,done:n=>!!n.all.pipe},{id:"mush",text:n=>n.theme==="bluffs"?"Bounce off a buoy":"Bounce off a mushroom",ok:n=>Do(n,"mush"),done:n=>!!n.all.mush},{id:"boost",text:"Ride the boost pad",ok:n=>Do(n,"boost"),done:n=>!!n.all.boost},{id:"current",text:"Ride the tide current",ok:n=>Do(n,"current"),done:n=>!!n.all.current},{id:"paddle",text:n=>n.theme==="bluffs"?"Get swatted by the ship's wheel":"Get swatted by a sunflower",ok:n=>Do(n,"paddle"),done:n=>!!n.all.paddle},{id:"bank",text:"Bank the winning putt off a wall",ok:()=>!0,done:n=>(n.fin.walls||0)>=1},{id:"clean",text:"Never touch a wall",ok:()=>!0,done:n=>n.walls===0},{id:"dry",text:"Stay dry \u2014 no splashes",ok:n=>n.water.length>0,done:n=>n.wet===0},{id:"birdie",text:"Make birdie or better",ok:n=>n.par>=2,done:n=>n.total<=n.par-1},{id:"long",text:"Sink a long bomb (from far away)",ok:()=>!0,done:n=>n.from>=40}],kh=(n,t)=>typeof n.text=="function"?n.text(t):n.text;function Tf(n,t){for(let e of["jump","pipe","mush","boost","current","paddle"])t[e]&&(n.all[e]=1);t.door==="sail"&&(n.all.sail=1),t.door==="barn"&&(n.all.barn=1),n.walls+=t.walls||0}var bf=n=>({total:0,par:n,fin:{},all:{},wet:0,walls:0,from:0});var Rf={android:{inter:"ca-app-pub-3940256099942544/1033173712",reward:"ca-app-pub-3940256099942544/5224354917"},ios:{inter:"ca-app-pub-3940256099942544/4411468910",reward:"ca-app-pub-3940256099942544/1712485313"}},Kl={gapSec:180,freeHoles:2,skipSec:5},zh={get(n,t){try{let e=JSON.parse(localStorage.getItem(n));return e==null?t:e}catch{return t}},set(n,t){try{localStorage.setItem(n,JSON.stringify(t))}catch{}}},Af={get(n,t){try{let e=JSON.parse(sessionStorage.getItem(n));return e==null?t:e}catch{return t}},set(n,t){try{sessionStorage.setItem(n,JSON.stringify(t))}catch{}}},Cf=()=>{try{let n=window.Capacitor;return n&&n.isNativePlatform&&n.isNativePlatform()&&n.Plugins&&n.Plugins.AdMob}catch{return null}},Pf=()=>{try{return window.Capacitor.getPlatform()==="ios"?"ios":"android"}catch{return"android"}};function If(n,t){let e=document.createElement("div");e.id="adbreak",e.innerHTML=`<div class="adbox"><div class="adtag">${n==="reward"?"REWARDED AD":"AD BREAK"} \xB7 TEST</div><div class="adart"><b>\u26F3</b><span>Your ad here</span><small>Real ads play in the Putt Party app</small></div><button id="adskip" disabled>Skip in ${Kl.skipSec}</button></div>`,document.body.appendChild(e),requestAnimationFrame(()=>e.classList.add("show"));let i=Kl.skipSec,s=e.querySelector("#adskip"),r=setInterval(()=>{i--,i>0?s.textContent=`Skip in ${i}`:(clearInterval(r),s.disabled=!1,s.textContent=n==="reward"?"Collect reward \u2713":"Close \u2715")},1e3);s.onclick=()=>{s.disabled||(e.classList.remove("show"),setTimeout(()=>e.remove(),300),t(!0))}}function Lf(n){let t=Af.get("pp_sess_holes",0)+1;Af.set("pp_sess_holes",t);let e=zh.get("pp_wallet",{}),i=zh.get("pp_ad_last",0),s=Date.now();if(e&&e.noAds||t<=Kl.freeHoles||s-i<Kl.gapSec*1e3)return n();zh.set("pp_ad_last",s);let r=Cf();if(r){let a=Rf[Pf()].inter;r.prepareInterstitial({adId:a,isTesting:!0}).then(()=>r.showInterstitial()).then(()=>n(),()=>n());return}If("inter",()=>n())}function Gh(n){let t=Cf();if(t){let e=Rf[Pf()].reward,i=!1,s=t.addListener&&t.addListener("onRewardedVideoAdReward",()=>{i=!0});t.prepareRewardVideoAd({adId:e,isTesting:!0}).then(()=>t.showRewardVideoAd()).then(r=>{try{s&&s.remove&&s.remove()}catch{}n(i||!!r)},()=>n(!1));return}If("reward",e=>n(e))}var lt=window.HOLE_DATA,ui=!!lt.look,us=lt.grid,$e=us.w,Pr=us.h,Go=us.res,Gf=Uint8Array.from(atob(us.b64),n=>n.charCodeAt(0)),i_=n=>n===1||n===4||n===5||n===6,Ye=new Float32Array($e*Pr);{let t=Math.SQRT2;for(let e=0;e<Ye.length;e++)Ye[e]=i_(Gf[e])?1e9:0;for(let e=0;e<Pr;e++)for(let i=0;i<$e;i++){let s=e*$e+i,r=Ye[s];r&&(i&&(r=Math.min(r,Ye[s-1]+1)),e&&(r=Math.min(r,Ye[s-$e]+1),i&&(r=Math.min(r,Ye[s-$e-1]+t)),i<$e-1&&(r=Math.min(r,Ye[s-$e+1]+t))),Ye[s]=r)}for(let e=Pr-1;e>=0;e--)for(let i=$e-1;i>=0;i--){let s=e*$e+i,r=Ye[s];r&&(i<$e-1&&(r=Math.min(r,Ye[s+1]+1)),e<Pr-1&&(r=Math.min(r,Ye[s+$e]+1),i<$e-1&&(r=Math.min(r,Ye[s+$e+1]+t)),i&&(r=Math.min(r,Ye[s+$e-1]+t))),Ye[s]=r)}for(let e=0;e<Ye.length;e++)Ye[e]=Ye[e]/Go}var Ys=(n,t)=>{let e=Math.floor((n-us.x0)*Go),i=Math.floor((t-us.y0)*Go);return e<0||i<0||e>=$e||i>=Pr?0:Gf[i*$e+e]};function Ni(n,t){let e=(n-us.x0)*Go-.5,i=(t-us.y0)*Go-.5,s=Math.floor(e),r=Math.floor(i),a=e-s,o=i-r,l=(c,h)=>c<0||h<0||c>=$e||h>=Pr?0:Ye[h*$e+c];return(l(s,r)*(1-a)+l(s+1,r)*a)*(1-o)+(l(s,r+1)*(1-a)+l(s+1,r+1)*a)*o}function s_(n,t){let i=Ni(n+.3,t)-Ni(n-.3,t),s=Ni(n,t+.3)-Ni(n,t-.3),r=Math.hypot(i,s)||1;return[i/r,s/r]}var Zt=1.4,sc=205,r_=.62,o_=11,Df=.72,Di=2,a_=4.2,Uf=600,de={x:lt.cup[0],y:lt.cup[1]},Oi=lt.heights||[];function Ue(n,t){let e=0;for(let i of Oi)n<i.x||n>i.x+i.w||t<i.y||t>i.y+i.h||(i.t==="hump"?e=Math.max(e,i.z*Math.sin(Math.PI*(t-i.y)/i.h)):i.t==="ramp"?e=Math.max(e,i.z0+(i.z1-i.z0)*(i.y+i.h-t)/i.h):i.t==="tier"&&(e=Math.max(e,i.z)));return e}function $h(n,t){return[(Ue(n+.35,t)-Ue(n-.35,t))/(2*.35),(Ue(n,t+.35)-Ue(n,t-.35))/(2*.35)]}var Lr=Ue(de.x,de.y),fn=lt.buildings.find(n=>n.door&&n.kind!=="barn"),l_=2*Math.PI/6.5,Vf=n=>n*l_,lu=n=>{if(!fn)return!1;let t=Vf(n);for(let e=0;e<4;e++){let i=((t+e*Math.PI/2-Math.PI)%(2*Math.PI)+3*Math.PI)%(2*Math.PI)-Math.PI;if(Math.abs(i)<.33)return!0}return!1},Wf=lt.buildings.filter(n=>n.door&&n.kind==="barn"),Xf=(n,t)=>{let e=n.period||3.4;return((t+(n.phase||0))%e+e)%e/e<(n.openFrac||.5)},cs=[];fn&&cs.push({x0:fn.door[0],x1:fn.door[1],y0:fn.y+fn.h-.2,y1:fn.y+fn.h+2.2,blocked:lu,kind:"sail"});for(let n of Wf)cs.push({x0:n.door[0],x1:n.door[1],y0:n.y+n.h-.4,y1:n.y+n.h+1.2,blocked:t=>!Xf(n,t),kind:"barn"});var qf=lt.extra.filter(n=>n.t==="bump").map(n=>({x:n.x,y:n.y,r:(n.r||3)*.95})),Fi=lt.extra.filter(n=>n.t==="critter"||n.t==="sheep").map((n,t)=>({kind:n.t,x0:n.x,y0:n.y,x:n.x,y:n.y,r:n.t==="sheep"?2.6:2,amp:n.p&&n.p.amp||(n.t==="sheep"?10:13),axis:n.p&&n.p.axis||"x",sp:.5+.9*(n.p&&n.p.speed||.3),ph:t*1.7+(n.p&&n.p.ph||0)})),cu=(n,t)=>{let e=Math.sin(t*n.sp+n.ph)*n.amp;n.axis==="y"?(n.x=n.x0,n.y=n.y0+e):(n.x=n.x0+e,n.y=n.y0)},On=lt.pipes&&lt.pipes.length?lt.pipes.map(n=>({ix:n[0],iy:n[1],ox:n[2],oy:n[3],col:n[4]||"#8a5d36",dir:n[5]||null})):lt.portals[0]&&lt.portals[1]?[{ix:lt.portals[0][0],iy:lt.portals[0][1],ox:lt.portals[1][0],oy:lt.portals[1][1],col:null,dir:lt.portalDir||null}]:[],zs=On[0]?{x:On[0].ix,y:On[0].iy}:null,No=On[0]?{x:On[0].ox,y:On[0].oy}:null,Rn=n=>lt.extra.filter(t=>t.t===n),pi=n=>{let t=(n.a||0)*Math.PI/180;return{x:n.x,y:n.y,hw:n.w/2,hh:n.h/2,c:Math.cos(t),s:Math.sin(t),a:t}},Zh=(n,t,e)=>{let i=t-n.x,s=e-n.y;return[i*n.c+s*n.s,-i*n.s+s*n.c]},Uo=(n,t,e,i=0)=>{let[s,r]=Zh(n,t,e);return Math.abs(s)<=n.hw+i&&Math.abs(r)<=n.hh+i},hu=Rn("mush").map(n=>({x:n.x,y:n.y,r:n.r||2.6,hitT:-9})),c_=Rn("hay").map(pi).concat(Rn("crate").map(pi)),Yf=Rn("rope").map(n=>{let t=n.x2-n.x1,e=n.y2-n.y1;return{...pi({x:(n.x1+n.x2)/2,y:(n.y1+n.y2)/2,w:Math.hypot(t,e),h:.9,a:Math.atan2(e,t)*180/Math.PI}),x1:n.x1,y1:n.y1,x2:n.x2,y2:n.y2}}),Jh=Rn("current").map(n=>({...pi(n),f:n.p&&n.p.f||200})),$f=Rn("boost").map(n=>({...pi(n),v:n.p&&n.p.v||175})),Vo=Rn("rough").map(pi),Kh=Rn("kicker").map(n=>({...pi(n),lift:n.p&&n.p.lift||2})),Ws=Rn("paddle").map(n=>({x:n.x,y:n.y,L:n.L||9,w:(n.p&&n.p.speed||1.1)*(n.p&&n.p.dir||1),arms:n.p&&n.p.arms||2,ph:n.p&&n.p.ph||0,r:.85})),uu=(n,t)=>n.ph+n.w*t,h_=330,Vh=95;function Ql(n,t,e,i,s=0,r=0){let a=n.vx-s,o=n.vy-r,l=a*t+o*e;return l>=0?0:(n.vx-=(1+i)*l*t,n.vy-=(1+i)*l*e,-l)}function u_(n,t){for(let e of Ws){let i=uu(e,t);if(!(Math.hypot(n.x-e.x,n.y-e.y)>e.L+e.r+Zt+.5)){if(Math.hypot(n.x-e.x,n.y-e.y)<1.6+Zt)return!0;for(let s=0;s<e.arms;s++){let r=i+s*2*Math.PI/e.arms,a=Math.cos(r),o=Math.sin(r),l=n.x-e.x,c=n.y-e.y,h=Math.max(0,Math.min(e.L,l*a+c*o));if(Math.hypot(l-a*h,c-o*h)<e.r+Zt+.02)return!0}}}for(let e of Fi)if(cu(e,t),Math.hypot(n.x-e.x,n.y-e.y)<e.r+Zt+.02)return!0;for(let e of cs)if(e.blocked(t)&&n.x>e.x0-Zt&&n.x<e.x1+Zt&&n.y>e.y0-Zt&&n.y<e.y1+Zt)return!0;return!1}function d_(n){for(let t of Ws)if(Math.hypot(n.x-t.x,n.y-t.y)<t.L+t.r+Zt+.5)return!0;for(let t of Fi){let e=t.axis==="y",i=(e?t.y0:t.x0)-t.amp-t.r-Zt-.5,s=(e?t.y0:t.x0)+t.amp+t.r+Zt+.5,r=e?n.y:n.x,a=e?n.x-t.x0:n.y-t.y0;if(r>i&&r<s&&Math.abs(a)<t.r+Zt+.5)return!0}for(let t of cs)if(n.x>t.x0-3&&n.x<t.x1+3&&n.y>t.y0-3&&n.y<t.y1+3)return!0;return!1}function Fo(n,t,e,i){if(n.state==="rest"&&!n.gone&&(Ws.length||Fi.length||cs.length)&&u_(n,e)&&(n.state="roll",n.restX=n.x,n.restY=n.y,n.ev=n.ev||{},n.swat=1),n.state!=="roll")return;let s=n.ev||(n.ev={}),r=Math.hypot(n.vx,n.vy),a=Math.max(1,Math.ceil(r*t/.33)),o=t/a;for(let f=0;f<a;f++){n.x+=n.vx*o,n.y+=n.vy*o;let x=e+f*o;n.air&&(n.az+=n.avz*o,n.avz-=h_*o,n.az<=0&&(n.az=0,n.air=!1,n.vx*=.55,n.vy*=.55,i&&i.land(n)));let M=!n.air||n.az<2.5;if(Oi.length&&!n.air){let[g,C]=$h(n.x,n.y);n.vx-=Uf*g*o,n.vy-=Uf*C*o}let m=Ni(n.x,n.y);if(m<Zt){let[g,C]=s_(n.x,n.y);n.x+=g*(Zt-m),n.y+=C*(Zt-m);let A=n.vx*g+n.vy*C;A<0&&(n.vx-=(1+Df)*A*g,n.vy-=(1+Df)*A*C,n.vx*=.97,n.vy*=.97,-A>25&&(s.walls=(s.walls||0)+1),i&&i.hit(n,-A,g,C))}for(let g of cs)!g.blocked(x)&&n.x>g.x0&&n.x<g.x1&&n.y>g.y0-3&&n.y<g.y0&&(s.door=g.kind);for(let g of cs)if(g.blocked(x)&&n.x>g.x0-Zt&&n.x<g.x1+Zt&&n.y>g.y0-Zt&&n.y<g.y1+Zt){let C=n.y>(g.y0+g.y1)/2;n.y=C?g.y1+Zt:g.y0-Zt,(C&&n.vy<0||!C&&n.vy>0)&&(n.vy=-n.vy*.8,n.vx+=(Math.random()-.5)*6,i&&i.hit(n,Math.abs(n.vy),0,C?1:-1,g.kind))}if(M){for(let g of hu){let C=n.x-g.x,A=n.y-g.y,_=Math.hypot(C,A),T=g.r+Zt;if(_<T&&_>1e-6){let v=C/_,y=A/_;if(n.x=g.x+v*T,n.y=g.y+y*T,Ql(n,v,y,1)>0){let P=n.vx*v+n.vy*y;P<Vh&&(n.vx+=(Vh-P)*v,n.vy+=(Vh-P)*y),g.hitT=x,s.mush=(s.mush||0)+1,i&&i.boing(n,g)}}}for(let g of c_.concat(Yf)){let[C,A]=Zh(g,n.x,n.y),_=Math.abs(C)-g.hw,T=Math.abs(A)-g.hh,v=Math.max(_,0),y=Math.max(T,0),w=Math.hypot(v,y),P=w>0?w:Math.max(_,T);if(P<Zt){let D,N;w>0?(D=Math.sign(C)*v/w,N=Math.sign(A)*y/w):_>T?(D=Math.sign(C),N=0):(D=0,N=Math.sign(A));let H=D*g.c-N*g.s,U=D*g.s+N*g.c;n.x+=H*(Zt-P),n.y+=U*(Zt-P);let k=Ql(n,H,U,.45);k>25&&(s.walls=(s.walls||0)+1),k>0&&i&&i.hit(n,k,H,U,"hay")}}for(let g of Ws){let C=uu(g,x);for(let A=0;A<g.arms;A++){let _=C+A*2*Math.PI/g.arms,T=Math.cos(_),v=Math.sin(_),y=n.x-g.x,w=n.y-g.y,P=Math.max(0,Math.min(g.L,y*T+w*v)),D=g.x+T*P,N=g.y+v*P,H=n.x-D,U=n.y-N,k=Math.hypot(H,U),F=g.r+Zt;if(k<F&&k>1e-6){let G=H/k,q=U/k;n.x=D+G*F,n.y=N+q*F;let et=-g.w*(N-g.y),nt=g.w*(D-g.x),rt=Ql(n,G,q,.6,et,nt);rt>0&&(s.paddle=1,i&&i.hit(n,rt,G,q,"paddle"))}}{let A=n.x-g.x,_=n.y-g.y,T=Math.hypot(A,_),v=1.6+Zt;if(T<v&&T>1e-6){let y=A/T,w=_/T;n.x=g.x+y*v,n.y=g.y+w*v,Ql(n,y,w,.6)}}}}if(!n.air){for(let g of Jh)Uo(g,n.x,n.y)&&(n.vx+=g.c*g.f*o,n.vy+=g.s*g.f*o,s.current=1);for(let g of $f)if(Uo(g,n.x,n.y)){let C=n.vx*g.c+n.vy*g.s;if(C<g.v){let A=Math.min(g.v-C,1500*o);n.vx+=g.c*A,n.vy+=g.s*A}s.boost||(s.boost=1,i&&i.boost(n,g))}for(let g=0;g<Kh.length;g++){let C=Kh[g],[A,_]=Zh(C,n.x,n.y);if(Math.abs(A)<=C.hw&&Math.abs(_)<=C.hh)n.kick=g,n.kz=C.lift*Math.max(0,Math.min(1,(A+C.hw)/(2*C.hw)));else if(n.kick===g){let v=n.vx*C.c+n.vy*C.s;A>C.hw&&v>30&&(n.air=!0,n.az=C.lift,n.avz=Math.min(75,v*.27),s.jump=1,i&&i.jump(n)),n.kick=-1,n.kz=0}}}if(M)for(let g of Fi)cu(g,x);if(M)for(let g of qf.concat(Fi)){let C=n.x-g.x,A=n.y-g.y,_=Math.hypot(C,A),T=g.r+Zt;if(_<T&&_>1e-6){let v=C/_,y=A/_;n.x=g.x+v*T,n.y=g.y+y*T;let w=n.vx*v+n.vy*y;if(w<0){let P=g.amp?.75:.95;n.vx-=(1+P)*w*v,n.vy-=(1+P)*w*y,i&&i.hit(n,-w,v,y,g.amp?"critter":"stump")}}}if(n.air)continue;if(Ys(n.x,n.y)===5){n.state="splash",n.timer=.75,n.penalty=(n.penalty||0)+1,i&&i.splash(n);return}for(let g=0;g<On.length;g++){let C=On[g],A=Math.hypot(n.x-C.ix,n.y-C.iy),_=Math.hypot(n.vx,n.vy);if(A<5.5&&A>1e-6&&_<120&&(n.vx+=(C.ix-n.x)/A*38*o,n.vy+=(C.iy-n.y)/A*38*o),A<3&&_<185){s.pipe=1,n.state="tunnel",n.pipe=g,n.timer=.8,n.tsp=Math.hypot(n.vx,n.vy),i&&i.burrow(n);return}}if(n.coins)for(let g of n.coins)!g.got&&Math.hypot(n.x-g.x,n.y-g.y)<Zt+(g.v>1?2.2:1.6)&&(g.got=!0,n.picked=(n.picked||0)+(g.v||1),i&&i.coin(g,n));let S=Math.hypot(n.x-de.x,n.y-de.y),E=Math.hypot(n.vx,n.vy);if(S<a_&&E<55&&(n.vx+=(de.x-n.x)/S*30*o,n.vy+=(de.y-n.y)/S*30*o),S<Di)if(E<92){n.state="sink",n.timer=0,n.sx=n.x,n.sy=n.y,i&&i.sink(n);return}else{let g=(Math.random()-.5)*.5,C=Math.cos(g),A=Math.sin(g),_=n.vx*C-n.vy*A,T=n.vx*A+n.vy*C;n.vx=_*.82,n.vy=T*.82}}if(n.air||n.state!=="roll")return;let l=Vo.some(f=>Uo(f,n.x,n.y)),c=Math.hypot(n.vx,n.vy),h=c*Math.exp(-r_*(l?3.6:1)*t)-o_*(l?3:1)*t,d=Oi.length?Math.hypot(...$h(n.x,n.y))>.035:!1,u=Jh.some(f=>Uo(f,n.x,n.y));h<2.2&&!d&&!u?(n.vx=n.vy=0,n.state="rest",n.restX=n.x,n.restY=n.y):h<.5?(n.vx*=.5,n.vy*=.5):(n.vx*=h/c,n.vy*=h/c)}function Oo(n,t,e){if(n.state==="splash")n.timer-=t,n.timer<=0&&(n.x=n.restX,n.y=n.restY,n.vx=n.vy=0,n.state="rest");else if(n.state==="tunnel"){if(n.timer-=t,n.timer<=0){let i=On[n.pipe||0],s,r;i.dir?(s=i.dir[0],r=i.dir[1]):(s=de.x-i.ox,r=de.y-i.oy);let a=Math.hypot(s,r)||1,o=Math.max(40,n.tsp*.62);n.x=i.ox+s/a*3.2,n.y=i.oy+r/a*3.2,n.vx=s/a*o,n.vy=r/a*o,n.state="roll",e&&e.popout(n,i)}}else if(n.state==="sink"){n.timer+=t;let i=Math.min(1,n.timer/.35);n.x=n.sx+(de.x-n.sx)*i,n.y=n.sy+(de.y-n.sy)*i,n.z=-Math.max(0,n.timer-.25)*14,n.timer>.75&&(n.state="done")}}function Zf(n,t){let e=d=>(d.state==="roll"||d.state==="rest")&&!d.air&&!d.gone;if(!e(n)||!e(t)||n.state==="rest"&&t.state==="rest")return 0;let i=t.x-n.x,s=t.y-n.y,r=Math.hypot(i,s);if(r>=2*Zt||r<1e-6)return 0;let a=i/r,o=s/r,l=2*Zt-r;n.x-=a*l/2,n.y-=o*l/2,t.x+=a*l/2,t.y+=o*l/2;let c=(n.vx-t.vx)*a+(n.vy-t.vy)*o;if(c<=0)return 0;let h=.96*c;n.vx-=h*a,n.vy-=h*o,t.vx+=h*a,t.vy+=h*o;for(let d of[n,t])d.state==="rest"&&Math.hypot(d.vx,d.vy)>3&&(d.restX=d.x,d.restY=d.y,d.state="roll",d.ev=d.ev||{});return h}var tn=1/60;function du(n,t,e,i,s,r=0,a=null){let o=Math.hypot(e,i)||1,l={x:n,y:t,vx:e/o*s*sc,vy:i/o*s*sc,state:"roll",restX:n,restY:t,z:0,coins:[]},c=a?{x:a[0],y:a[1],vx:0,vy:0,state:"rest",restX:a[0],restY:a[1],z:0,coins:[]}:null,h=r;for(let d=0;d<1800;d++)if(Fo(l,tn,h,null),Oo(l,tn,null),c&&(Fo(c,tn,h,null),Oo(c,tn,null),Zf(l,c)),h+=tn,(l.state==="rest"||l.state==="done")&&(!c||c.state!=="roll")){if(l.state==="done"||l.watched>=4.5||!d_(l))break;l.watched=(l.watched||0)+tn}return{sunk:l.state==="done"||l.state==="sink",x:l.x,y:l.y,penalty:l.penalty||0,state:l.state,ev:l.ev||{}}}var f_=document.getElementById("gl"),Hi=document.getElementById("fx"),p_=Hi.getContext("2d"),Gi=new $l({canvas:f_,antialias:!0,powerPreference:"high-performance"});Gi.setPixelRatio(Math.min(2,window.devicePixelRatio||1));Gi.shadowMap.enabled=!0;Gi.shadowMap.type=Ka;Gi.outputColorSpace=Pe;Gi.toneMapping=ol;Gi.toneMappingExposure=1.08;var Xt=new dr,en=new on(30,1,1,3e3),Jf=new xo,m_=(n,t)=>{let e=Jf.load(n);return e.colorSpace=Pe,e.anisotropy=8,t&&(e.wrapS=e.wrapT=hr,e.repeat.set(t,t)),e},jn=(n,t,e,i)=>{let s=document.createElement("canvas");s.width=n,s.height=t,e(s.getContext("2d"),n,t);let r=new Qe(s);return r.colorSpace=Pe,r.anisotropy=8,i&&(r.wrapS=r.wrapT=Ge),r},vn=(n,t,e,i)=>{let s=Jf.load(n);return i&&(s.colorSpace=Pe),s.wrapS=s.wrapT=Ge,s.repeat.set(t,e),s.anisotropy=8,s},Bt=(()=>{let n=1234567;return()=>(n=n*16807%2147483647,n/2147483647)})(),Hn=1e9,Qn=-1e9,En=1e9,Bn=-1e9;for(let n of lt.walls)for(let[t,e]of n.outer)Hn=Math.min(Hn,t),Qn=Math.max(Qn,t),En=Math.min(En,e),Bn=Math.max(Bn,e);var Vs=(Hn+Qn)/2,$o=(En+Bn)/2,ae={...vf[lt.theme||"meadow"]};ui&&ae.surface==="grass"&&(ae.turf=[34,138,44],ae.turfAlt=[48,160,54]);Xt.add(new _o(ae.hemiSky,ae.hemiGround,.8));{let n=new Tr(Gi),t=new dr,e=document.createElement("canvas");e.width=8,e.height=256;let i=e.getContext("2d"),s=i.createLinearGradient(0,0,0,256),r=new Ot(ae.hemiSky),a=new Ot(ae.hemiGround),o=r.clone().lerp(new Ot(16777215),.6);s.addColorStop(0,"#"+r.getHexString()),s.addColorStop(.47,"#"+o.getHexString()),s.addColorStop(.53,"#"+a.clone().lerp(o,.3).getHexString()),s.addColorStop(1,"#"+a.getHexString()),i.fillStyle=s,i.fillRect(0,0,8,256);let l=new Qe(e);l.colorSpace=Pe,t.add(new $(new ye(50,32,16),new Se({map:l,side:je})));let c=new $(new ye(4,12,8),new Se({color:new Ot(ae.sun).multiplyScalar(6)}));c.position.set(-28,33,-32),t.add(c),Xt.environment=n.fromScene(t,.03).texture,Xt.environmentIntensity=.5,n.dispose()}Xt.fog=new no(ae.fog,400,1400);var Bi=new Mo(ae.sun,2.9);Bi.position.set(Vs-70,110,$o-80);Bi.target.position.set(Vs,0,$o);Bi.castShadow=!0;Bi.shadow.mapSize.set(2048,2048);var ds=Bi.shadow.camera;ds.left=-((Qn-Hn)/2+40);ds.right=-ds.left;ds.top=(Bn-En)/2+50;ds.bottom=-ds.top;ds.near=10;ds.far=400;Bi.shadow.bias=-6e-4;Bi.shadow.normalBias=.4;Xt.add(Bi,Bi.target);var Kf=300,Qf=Math.max(360,Bn-En+230),fu=new Qe(Ef(ae,1024,Math.round(1024*Qf/Kf)));fu.colorSpace=Pe;fu.anisotropy=8;var hc=new $(new we(Kf,Qf),new xr({map:fu}));hc.rotation.x=-Math.PI/2;hc.position.set(Vs,-.05,$o+20);hc.receiveShadow=!0;Xt.add(hc);var pu=new $(new we(2e3,2e3),new xr({color:new Ot(ae.ground[0])}));pu.rotation.x=-Math.PI/2;pu.position.set(Vs,-.2,$o);Xt.add(pu);var jf=jn(256,256,(n,t,e)=>{n.fillStyle="#a4703e",n.fillRect(0,0,t,e);for(let i=0;i<260;i++){n.strokeStyle=`rgba(${70+Bt()*40},${40+Bt()*20},${18+Bt()*10},${.12+Bt()*.18})`,n.lineWidth=1+Bt()*2;let s=Bt()*e;n.beginPath(),n.moveTo(0,s),n.bezierCurveTo(t*.3,s+Bt()*6-3,t*.7,s+Bt()*6-3,t,s),n.stroke()}for(let i=0;i<t;i+=64)n.fillStyle="rgba(50,28,12,.55)",n.fillRect(i,0,2,e);n.fillStyle="rgba(255,220,170,.10)",n.fillRect(0,0,t,e*.35)},!0),mu=jn(256,256,(n,t,e)=>{n.fillStyle="#5d5952",n.fillRect(0,0,t,e);let i=6,s=e/i;for(let r=0;r<i;r++){let a=-Bt()*30;for(;a<t;){let o=28+Bt()*34,l=120+Bt()*50,c=Bt()*16;n.fillStyle=`rgb(${l+c},${l+c*.6},${l-6})`;let h=r*s+2;n.beginPath(),n.roundRect?n.roundRect(a+2,h,o-4,s-4,7):n.rect(a+2,h,o-4,s-4),n.fill(),n.fillStyle="rgba(255,255,255,.10)",n.fillRect(a+4,h+2,o-10,4),n.fillStyle="rgba(0,0,0,.18)",n.fillRect(a+4,h+s-9,o-10,4),a+=o}}},!0);jf.repeat.set(.09,.09);mu.repeat.set(.07,.16);var tp=jn(256,256,(n,t,e)=>{n.fillStyle="#9a9d97",n.fillRect(0,0,t,e);let i=4,s=e/i;for(let r=0;r<i;r++){let a=-Bt()*60-r%2*40;for(;a<t;){let o=70+Bt()*50,l=175+Bt()*35;n.fillStyle=`rgb(${l},${l+3},${l-4})`;let c=r*s+3;n.beginPath(),n.roundRect?n.roundRect(a+3,c,o-6,s-6,10):n.rect(a+3,c,o-6,s-6),n.fill();for(let h=0;h<40;h++)n.fillStyle=`rgba(${Bt()<.5?"60,62,60":"255,255,255"},${.08+Bt()*.12})`,n.fillRect(a+3+Bt()*(o-8),c+Bt()*(s-8),2,2);n.fillStyle="rgba(255,255,255,.14)",n.fillRect(a+6,c+3,o-14,5),n.fillStyle="rgba(0,0,0,.16)",n.fillRect(a+6,c+s-12,o-14,5),a+=o}}},!0);tp.repeat.set(.06,.2);var rc={woodstone:[new Lt({map:jf,roughness:.75}),new Lt({map:mu,roughness:.92})],granite:[new Lt({color:14606298,roughness:.8}),new Lt({map:tp,roughness:.88})]};if(ui&&lt.pbr){let n=lt.pbr;n.wood&&n.stone&&(rc.woodstone=[new ri({map:vn(n.wood.color,.07,.07,!0),normalMap:vn(n.wood.normal,.07,.07),roughnessMap:vn(n.wood.rough,.07,.07),color:14260834,clearcoat:.35,clearcoatRoughness:.35,envMapIntensity:.6}),new Lt({map:vn(n.stone.color,.06,.16,!0),normalMap:vn(n.stone.normal,.06,.16),roughnessMap:vn(n.stone.rough,.06,.16),normalScale:new at(1.4,1.4)})]),n.block&&(rc.granite=[new Lt({color:15132642,roughness:.7,normalMap:vn(n.rock.normal,.08,.08),normalScale:new at(.4,.4)}),new Lt({map:vn(n.block.color,.07,.2,!0),normalMap:vn(n.block.normal,.07,.2),roughnessMap:vn(n.block.rough,.07,.2),color:16053230,normalScale:new at(1.2,1.2)})])}var[Qh,g_]=rc[ae.wall||"woodstone"],x_=(n,t)=>{let e=0;for(let i=-5;i<=5;i+=2.5)for(let s=-5;s<=5;s+=2.5)e=Math.max(e,Ue(n+i,t+s));return e},Nf=n=>{if(!Oi.length)return n;let t=[];for(let e=0;e<n.length;e++){let[i,s]=n[e],[r,a]=n[(e+1)%n.length],o=Math.max(1,Math.ceil(Math.hypot(r-i,a-s)/1.5));for(let l=0;l<o;l++)t.push([i+(r-i)*l/o,s+(a-s)*l/o])}return t};for(let n of lt.walls){let t=new ln(Nf(n.outer).map(([s,r])=>new at(s,-r)));for(let s of n.holes)t.holes.push(new Rs(Nf(s).map(([r,a])=>new at(r,-a))));let e=new si(t,{depth:lt.wallH,bevelEnabled:!0,bevelThickness:ae.wall==="granite"?.8:ui?1:.45,bevelSize:ae.wall==="granite"?.75:ui?.5:.4,bevelSegments:ae.wall==="granite"||ui?4:2,curveSegments:4});if(e.rotateX(-Math.PI/2),Oi.length){let s=e.attributes.position;for(let r=0;r<s.count;r++)s.getY(r)>.5&&s.setY(r,s.getY(r)+x_(s.getX(r),s.getZ(r)));e.computeVertexNormals()}let i=new $(e,[Qh,g_]);i.castShadow=i.receiveShadow=!0,Xt.add(i)}var re=8,fs=Math.ceil((Qn-Hn+4)*re),ps=Math.ceil((Bn-En+4)*re),Ho=Hn-2,Bo=En-2,y_=jn(fs,ps,(n,t,e)=>{let i=n.createImageData(t,e),s=i.data;for(let l=0;l<e;l++)for(let c=0;c<t;c++){let h=Ho+(c+.5)/re,d=Bo+(l+.5)/re,u=Ys(h,d),f=(l*t+c)*4;if(u===1||u===4){let x=ae.surface==="grass"?Math.floor((h*.55+d)/7)%2:Math.sin(h*.11+Math.sin(d*.07)*2.2)+Math.sin(d*.09-h*.05)>.6?1:0,M=x?ae.turf:ae.turfAlt,m=Ni(h,d),p=ui?1-.38*Math.exp(-m/1.8):1-.3*Math.exp(-m/.9),S=m>.9&&m<2.2?1.05:1,E=.965+.07*(.5+.25*Math.sin(h*.37+Math.sin(d*.21)*2)+.25*Math.sin(d*.29-h*.13)),g=.95+.1*Math.random(),C=p*S*E*g*(u===4?.45:1);if(Oi.length){let[A,_]=$h(h,d),T=Ue(h,d);C*=Math.max(.68,Math.min(1.3,1+_*1.5-A*.5))*(1+T*.035)}Vo.some(A=>Uo(A,h,d))&&(C*=.78),s[f]=M[0]*C,s[f+1]=M[1]*C,s[f+2]=M[2]*C,s[f+3]=255}else s[f+3]=0}if(n.putImageData(i,0,0),ae.surface==="grass")for(let l=0;l<t*e/26;l++){let c=Math.random()*t,h=Math.random()*e;n.strokeStyle=Math.random()<.5?"rgba(20,60,10,.10)":"rgba(220,255,180,.07)",n.lineWidth=1,n.beginPath(),n.moveTo(c,h),n.lineTo(c+(Math.random()-.5)*2,h-2-Math.random()*3),n.stroke()}else for(let l=0;l<t*e/18;l++){let c=Math.random()*t,h=Math.random()*e,d=Math.random();n.fillStyle=d<.45?"rgba(20,40,60,.13)":d<.9?"rgba(235,250,255,.12)":"rgba(255,255,255,.35)",n.fillRect(c,h,1+Math.random()*1.5,1+Math.random()*1.5)}{let l=(lt.tee[0]-Ho)*re,c=(lt.tee[1]-Bo)*re;n.fillStyle="rgba(30,80,30,.35)",n.beginPath(),n.roundRect?n.roundRect(l-5*re,c-3.2*re,10*re,6.4*re,1.4*re):n.rect(l-5*re,c-3.2*re,10*re,6.4*re),n.fill(),n.fillStyle="#ffffff";for(let h of[-3.6,3.6])n.beginPath(),n.arc(l+h*re,c,.7*re,0,7),n.fill()}let r=(de.x-Ho)*re,a=(de.y-Bo)*re;{let l=n.createRadialGradient(r,a,Di*re,r,a,(Di+2.4)*re);l.addColorStop(0,"rgba(0,30,0,.28)"),l.addColorStop(1,"rgba(0,30,0,0)"),n.fillStyle=l,n.beginPath(),n.arc(r,a,(Di+2.4)*re,0,7),n.fill()}n.fillStyle="#f3efe6",n.beginPath(),n.arc(r,a,(Di+.35)*re,0,7),n.fill();let o=n.createRadialGradient(r,a-2,0,r,a,Di*re);o.addColorStop(0,"#020302"),o.addColorStop(1,"#16200f"),n.fillStyle=o,n.beginPath(),n.arc(r,a,Di*re,0,7),n.fill()}),jh=new we(fs/re,ps/re,Oi.length?Math.ceil(fs/re*1.5):1,Oi.length?Math.ceil(ps/re*1.5):1),__=(()=>{let n=document.createElement("canvas");n.width=n.height=256;let t=n.getContext("2d");if(t.fillStyle="#808080",t.fillRect(0,0,256,256),ae.surface==="grass")for(let i=0;i<9e3;i++){let s=Math.random()*256,r=Math.random()*256,a=Math.random()<.5?40:215;t.strokeStyle=`rgba(${a},${a},${a},.55)`,t.lineWidth=1,t.beginPath(),t.moveTo(s,r),t.lineTo(s+(Math.random()-.5)*1.5,r-2-Math.random()*3),t.stroke()}else{for(let i=0;i<120;i++){let s=Math.random()*256,r=Math.random()*256,a=8+Math.random()*30,o=t.createRadialGradient(s,r,0,s,r,a),l=Math.random()<.5?100:160;o.addColorStop(0,`rgba(${l},${l},${l},.5)`),o.addColorStop(1,`rgba(${l},${l},${l},0)`),t.fillStyle=o,t.fillRect(s-a,r-a,2*a,2*a)}t.strokeStyle="rgba(60,60,60,.35)";for(let i=0;i<14;i++){t.beginPath();let s=Math.random()*256,r=Math.random()*256;t.moveTo(s,r);for(let a=0;a<6;a++)s+=(Math.random()-.5)*40,r+=(Math.random()-.5)*40,t.lineTo(s,r);t.stroke()}}let e=new Qe(n);return e.wrapS=e.wrapT=Ge,e.repeat.set(fs/re/(ae.surface==="grass"?7:26),ps/re/(ae.surface==="grass"?7:26)),e.anisotropy=8,e})(),Ii=new Lt({map:y_,bumpMap:__,bumpScale:ae.surface==="grass"?.9:.35,roughness:ae.surfRough||.96,metalness:ae.surface==="slate"?.08:0,alphaTest:.5,envMapIntensity:ae.surface==="slate"?1.3:.35});if(ui&&lt.pbr){let n=fs/re,t=ps/re;if(Ii.bumpMap=null,lt.pbr.grass){let i=n/9,s=t/9;Ii.normalMap=vn(lt.pbr.grass.normal,i,s),Ii.normalScale=new at(1.1,1.1),Ii.roughnessMap=vn(lt.pbr.grass.rough,i,s),Ii.roughness=1;let r=vn(lt.pbr.grass.color,i,s,!0);Ii.onBeforeCompile=a=>{a.uniforms.detMap={value:r},a.uniforms.detRep={value:new at(i,s)},a.fragmentShader=`uniform sampler2D detMap; uniform vec2 detRep;
`+a.fragmentShader.replace("#include <map_fragment>",`#include <map_fragment>
{ vec3 dc = texture2D(detMap, vMapUv * detRep).rgb; float l = dot(dc, vec3(0.299, 0.587, 0.114)); diffuseColor.rgb *= 0.5 + l * 2.1; diffuseColor.g *= 1.06; }`)}}else lt.pbr.rock&&(Ii.normalMap=vn(lt.pbr.rock.normal,n/28,t/28),Ii.normalScale=new at(.35,.35))}var Dr=new $(jh,Ii);if(Oi.length){let n=jh.attributes.position,t=Ho+fs/re/2,e=Bo+ps/re/2;for(let i=0;i<n.count;i++)n.setZ(i,Ue(t+n.getX(i),e-n.getY(i)));jh.computeVertexNormals()}Dr.rotation.x=-Math.PI/2;Dr.position.set(Ho+fs/re/2,.03,Bo+ps/re/2);Dr.receiveShadow=!0;Xt.add(Dr);{let n=new $(new _n(Di+.12,.2,10,40),new ri({color:16184298,roughness:.35,clearcoat:.6}));n.rotation.x=-Math.PI/2,n.position.set(de.x,Ue(de.x,de.y)+.04,de.y),n.receiveShadow=!0,Xt.add(n)}{let n=new $(new we(fs/re,ps/re),new Se({color:1845780}));n.rotation.x=-Math.PI/2,n.position.set(Dr.position.x,-.6,Dr.position.z),Xt.add(n)}var ep=[],np=[];for(let[n,t,e,i]of lt.water){let s=jn(256,256,(a,o,l)=>{let c=a.createLinearGradient(0,0,0,l);c.addColorStop(0,ae.water[0]),c.addColorStop(1,ae.water[1]),a.fillStyle=c,a.fillRect(0,0,o,l);for(let h=0;h<90;h++){a.strokeStyle=`rgba(255,255,255,${.12+Bt()*.25})`,a.lineWidth=1+Bt()*2;let d=Bt()*l,u=Bt()*o,f=10+Bt()*30;a.beginPath(),a.moveTo(u,d),a.quadraticCurveTo(u+f/2,d-3,u+f,d),a.stroke()}},!0);s.repeat.set(e/14,i/14);let r=new $(new we(e,i),new Lt({map:s,roughness:.15,metalness:.1,transparent:!0,opacity:.94}));r.rotation.x=-Math.PI/2,r.position.set(n+e/2,0,t+i/2),r.receiveShadow=!0,Xt.add(r),ep.push(s),np.push([r,e,i])}for(let[n,t,e,i]of lt.decks){for(let s=t+.55;s<t+i;s+=1.15){let r=new $(new Ee(e+1.6,.5,1),Qh);r.position.set(n+e/2,.22,s),r.castShadow=r.receiveShadow=!0,Xt.add(r)}for(let[s,r]of[[n-.9,t],[n+e+.9,t],[n-.9,t+i],[n+e+.9,t+i]]){let a=new $(new oe(.45,.5,3.2,8),Qh);a.position.set(s,1.6,r),a.castShadow=!0,Xt.add(a)}}var Gs=null,ko=null;if(fn){let n=fn,t=7,e=5.2,i=n.y+n.h,s=n.x+n.w/2,r=n.y+n.h/2,a=new Lt({map:mu,roughness:.95}),o=(A,_,T,v,y,w,P)=>{let D=new $(new Ee(_-A,v-T,w-y),P);return D.position.set((A+_)/2,(T+v)/2,(y+w)/2),D.castShadow=D.receiveShadow=!0,Xt.add(D),D};o(n.x,n.door[0],0,t,n.y,i,a),o(n.door[1],n.x+n.w,0,t,n.y,i,a),o(n.door[0],n.door[1],e,t,n.y,i,a),o(n.door[0]-.01,n.door[0]+.02,0,e,n.y,i,new Se({color:1182728})),o(n.door[1]-.02,n.door[1]+.01,0,e,n.y,i,new Se({color:1182728}));let l=o(n.door[0],n.door[1],e-.05,e,n.y,i,new Se({color:1708556})),c=jn(256,256,(A,_,T)=>{A.fillStyle="#efe7d6",A.fillRect(0,0,_,T);for(let v=0;v<1400;v++)A.fillStyle=`rgba(${150+Bt()*60},${140+Bt()*50},${120+Bt()*40},${.05+Bt()*.08})`,A.fillRect(Bt()*_,Bt()*T,2+Bt()*6,2+Bt()*6)}),h=Math.min(n.w,n.h)*.44,d=h*.66,u=24,f=new $(new oe(d,h,u,10),new Lt({map:c,roughness:.9}));f.position.set(s,t+u/2,r),f.castShadow=f.receiveShadow=!0,Xt.add(f);let x=new $(new un(d*1.3,8,10),new Lt({color:11027244,roughness:.8}));x.position.set(s,t+u+4,r),x.castShadow=!0,Xt.add(x);let M=new $(new yn(1.1,16),new Se({color:2759698}));M.position.set(s,t+u*.45,r+(h+d)/2+.05),M.rotation.x=-.12,Xt.add(M),Gs=new he;let m=r+d+1.2,p=t+u*.72,S=Math.max(12,p-3.2),E=new Lt({color:15919312,roughness:.85,side:Ce}),g=new Lt({color:5913634,roughness:.8});for(let A=0;A<4;A++){let _=new he;_.rotation.z=A*Math.PI/2;let T=new $(new Ee(.7,S,.6),g);T.position.y=S/2,T.castShadow=!0,_.add(T);let v=new $(new we(S*.27,S*.78),E);v.position.set(S*.17,S*.58,.1),v.castShadow=!0,_.add(v);for(let y=0;y<5;y++){let w=new $(new Ee(S*.28,.25,.3),g);w.position.set(S*.17,S*(.22+y*.18),.2),_.add(w)}Gs.add(_)}let C=new $(new oe(1.1,1.3,1.6,12),g);C.rotation.x=Math.PI/2,Gs.add(C),Gs.position.set(s,p,m),Xt.add(Gs),ko=new $(new ye(1.1,16,12),new Lt({color:4259696,emissive:3199056,emissiveIntensity:1.6})),ko.position.set(s,t+.9,i+.6),Xt.add(ko)}var ip=[];for(let n of Wf){let i=n.y+n.h,s=new Lt({color:10893866,roughness:.85}),r=new Lt({color:15920610,roughness:.8}),a=(u,f,x,M,m,p,S)=>{let E=new $(new Ee(f-u,M-x,p-m),S);return E.position.set((u+f)/2,(x+M)/2,(m+p)/2),E.castShadow=E.receiveShadow=!0,Xt.add(E),E};a(n.x,n.door[0],0,10,n.y,i,s),a(n.door[1],n.x+n.w,0,10,n.y,i,s),a(n.door[0],n.door[1],6.5,10,n.y,i,s),a(n.door[0]-.6,n.door[0],0,6.5+.6,i-.01,i+.25,r),a(n.door[1],n.door[1]+.6,0,6.5+.6,i-.01,i+.25,r),a(n.door[0]-.6,n.door[1]+.6,6.5,6.5+.6,i-.01,i+.25,r),a(n.door[0],n.door[1],6.5-.05,6.5,n.y,i,new Se({color:1708556}));let o=new ln([new at(-n.w/2-1,0),new at(n.w/2+1,0),new at(0,7)].map(u=>u)),l=new si(o,{depth:n.h+2,bevelEnabled:!1});l.translate(0,0,-(n.h+2)/2);let c=new $(l,new Lt({color:5981750,roughness:.9}));c.position.set(n.x+n.w/2,10,n.y+n.h/2),c.castShadow=!0,Xt.add(c);let h=(n.door[1]-n.door[0])/2,d=(u,f)=>{let x=new he;x.position.set(u,0,i+.15),Xt.add(x);let M=new $(new Ee(h,6.5-.1,.5),s);M.position.set(f*h/2,(6.5-.1)/2,0),M.castShadow=!0,x.add(M);for(let m of[.85,-.85]){let p=new $(new Ee(.4,Math.hypot(h,6.5)*.92,.55),r);p.position.copy(M.position),p.rotation.z=m*Math.atan2(h,6.5),x.add(p)}return x};ip.push({b:n,l:d(n.door[0],1),r:d(n.door[1],-1),a:0})}var VE=new Lt({color:9067830,roughness:1}),WE=new Se({color:722693}),ze=Sf({scene:Xt,hAt:Ue,theme:lt.theme||"meadow",cellAt:Ys});for(let[n,t,e]of np)ze.clip(n,t,e,128,i=>i===5);for(let[n,t,e,i]of lt.water)ze.waterEdge(n,t,e,i);if(zs&&!On[0].col){ze.burrow(zs.x,zs.y,!0);let n=new $(new oe(.3,.3,6,6),new Lt({color:7031339}));n.position.set(zs.x+6.2,3,zs.y-3.4),n.castShadow=!0,Xt.add(n);let t=new $(new we(10,4.2),new Lt({side:Ce,map:jn(256,110,(e,i,s)=>{e.fillStyle="#c9965a",e.fillRect(0,0,i,s),e.strokeStyle="#6b4a2b",e.lineWidth=8,e.strokeRect(4,4,i-8,s-8),e.fillStyle="#3b2716",e.font="bold 46px Fredoka, sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText("\u{1F407} Burrow",i/2,s/2+2)})}));t.position.set(zs.x+6.2,6.4,zs.y-3.3),t.rotation.x=-.5,t.castShadow=!0,Xt.add(t)}No&&!On[0].col&&ze.burrow(No.x,No.y,!1);for(let n of On)n.col&&(ze.pipeMouth(n.ix,n.iy,n.col,!0),ze.pipeMouth(n.ox,n.oy,n.col,!1));for(let n of qf)ze.stump(n);var v_=new Lt({color:16052714,roughness:1}),Ff=new Lt({color:2827554,roughness:.8});function M_(){let n=new he;for(let[e,i,s,r]of[[0,2.4,0,2.1],[1.2,2.6,.3,1.5],[-1.2,2.5,-.2,1.6],[0,3.3,.2,1.4],[.2,2.5,-1.1,1.4],[-.1,2.5,1.1,1.4]]){let a=new $(new ye(r,14,10),v_);a.position.set(e,i,s),a.castShadow=!0,n.add(a)}let t=new $(new ye(.95,14,10),Ff);t.scale.set(1.25,1,1),t.position.set(2.7,3,0),t.castShadow=!0,n.add(t);for(let[e,i]of[[1.1,.8],[1.1,-.8],[-1.1,.8],[-1.1,-.8]]){let s=new $(new oe(.28,.28,1.6,6),Ff);s.position.set(e,.8,i),n.add(s)}return Xt.add(n),n}var Wh=Fi.map(n=>n.kind==="sheep"?M_():ze.critter()),E_=new oe(1.25,1.25,.32,24),S_=new Lt({color:16762938,metalness:.85,roughness:.28,emissive:4861952}),Zo=lt.extra.filter(n=>n.t==="coin"||n.t==="gem").map(n=>{let t=new he,e=new $(E_,S_);return e.rotation.x=Math.PI/2,e.castShadow=!0,t.add(e),t.position.set(n.x,2.2+Ue(n.x,n.y),n.y),Xt.add(t),{x:n.x,y:n.y,m:t,got:!1,h:Ue(n.x,n.y)}});{let n=new ln;for(let i=0;i<10;i++){let s=i%2?.75:1.7,r=-Math.PI/2+i*Math.PI/5;i?n.lineTo(Math.cos(r)*s,Math.sin(r)*s):n.moveTo(Math.cos(r)*s,Math.sin(r)*s)}let t=new si(n,{depth:.5,bevelEnabled:!0,bevelThickness:.15,bevelSize:.12,bevelSegments:1});t.center();let e=new Lt({color:16765498,metalness:.7,roughness:.25,emissive:9067008,emissiveIntensity:.8});for(let i of Rn("star")){let s=new he,r=new $(t,e);r.castShadow=!0,s.add(r),s.position.set(i.x,2.6+Ue(i.x,i.y),i.y),Xt.add(s),Zo.push({x:i.x,y:i.y,m:s,got:!1,h:Ue(i.x,i.y)+.6,v:5,star:!0})}}var w_=hu.map(n=>ze.bouncer(n));Rn("hay").forEach(n=>ze.block(pi(n),"hay"));Rn("crate").forEach(n=>ze.block(pi(n),"crate"));Yf.forEach(n=>ze.ropeRail(n));Jh.forEach(n=>ze.current(n));Rn("boardwalk").forEach(n=>ze.boardwalk(pi(n)));var T_=jn(128,128,(n,t,e)=>{n.clearRect(0,0,t,e),n.fillStyle=ae.accent,n.strokeStyle="rgba(255,255,255,.9)",n.lineWidth=5;for(let i of[8,72])n.beginPath(),n.moveTo(i,22),n.lineTo(i+34,64),n.lineTo(i,106),n.lineTo(i+16,106),n.lineTo(i+50,64),n.lineTo(i+16,22),n.closePath(),n.fill(),n.stroke()},!0),sp=[],b_=$f.map(n=>{let t=T_.clone();t.needsUpdate=!0,t.wrapS=t.wrapT=Ge,t.repeat.set(n.hw/3,1);let e=new $(new we(n.hw*2+.8,n.hh*2+.8),new Lt({color:2845230,roughness:.6}));e.rotation.x=-Math.PI/2,e.rotation.z=-n.a,e.position.set(n.x,Ue(n.x,n.y)+.06,n.y),e.receiveShadow=!0,Xt.add(e);let i=new $(new we(n.hw*2,n.hh*2),new Se({map:t,transparent:!0,depthWrite:!1}));if(i.rotation.x=-Math.PI/2,i.rotation.z=-n.a,i.position.set(n.x,Ue(n.x,n.y)+.1,n.y),Xt.add(i),ze.clip(i,n.hw*2,n.hh*2),ze.clip(e,n.hw*2+.8,n.hh*2+.8),ui){e.material.color.set(2303789),e.material.metalness=.6,e.material.roughness=.35,i.material.blending=Eo,sp.push(i.material);let s=new Lt({color:12174028,metalness:.85,roughness:.28}),r=new he,a=n.hw*2+1.4,o=n.hh*2+1.4;for(let[l,c,h,d]of[[a,.7,0,-o/2],[a,.7,0,o/2],[.7,o,-a/2,0],[.7,o,a/2,0]]){let u=new $(new Ee(l,.45,c),s);u.position.set(h,.2,d),u.castShadow=!0,r.add(u)}for(let[l,c]of[[-a/2,-o/2],[a/2,-o/2],[-a/2,o/2],[a/2,o/2]]){let h=new $(new oe(.28,.28,.2,10),new Lt({color:ae.accent,emissive:ae.accent,emissiveIntensity:.6}));h.position.set(l,.48,c),r.add(h)}r.rotation.y=-n.a,r.position.set(n.x,Ue(n.x,n.y),n.y),Xt.add(r)}return t});if(ui){let n=jn(128,128,(u,f,x)=>{u.fillStyle="#5a3d25",u.fillRect(0,0,f,x);for(let M=0;M<500;M++)u.fillStyle=`rgba(${Bt()<.5?"30,18,8":"140,100,60"},${.2+Bt()*.3})`,u.beginPath(),u.arc(Bt()*f,Bt()*x,1+Bt()*3,0,7),u.fill()},!0),t=rc.woodstone[0],e=new oe(.09,.12,1,5),i=new Ai(.62,0),s=new un(.45,1.1,4),r=0;for(let u of Vo)r+=Math.round(u.hw*u.hh*4*.42);let a=new He(e,new Lt({color:4161322}),Math.max(1,r)),o=new He(i,new Lt({roughness:.6,flatShading:!0}),Math.max(1,r)),l=new He(s,new Lt({color:5216820,flatShading:!0}),Math.max(1,r));o.castShadow=!0;let c=new Oe,h=new Ot,d=0;for(let u of Vo){let f=Ue(u.x,u.y),x=new $(new we(u.hw*2,u.hh*2),new Lt({map:n,roughness:1}));n.repeat.set(u.hw/4,u.hh/4),x.rotation.x=-Math.PI/2,x.rotation.z=-u.a,x.position.set(u.x,f+.07,u.y),x.receiveShadow=!0,Xt.add(x);let M=new he;for(let[p,S,E,g]of[[u.hw*2+.9,.45,0,-u.hh],[u.hw*2+.9,.45,0,u.hh],[.45,u.hh*2,-u.hw,0],[.45,u.hh*2,u.hw,0]]){let C=new $(new Ee(p,.4,S),t);C.position.set(E,.2,g),C.castShadow=C.receiveShadow=!0,M.add(C)}M.rotation.y=-u.a,M.position.set(u.x,f,u.y),Xt.add(M);let m=Math.round(u.hw*u.hh*4*.42);for(let p=0;p<m&&d<r;p++,d++){let S=(Bt()*2-1)*(u.hw-.7),E=(Bt()*2-1)*(u.hh-.7),g=u.x+S*u.c-E*u.s,C=u.y+S*u.s+E*u.c,A=.9+Bt()*.9;c.position.set(g,f+A/2,C),c.rotation.set((Bt()-.5)*.3,0,(Bt()-.5)*.3),c.scale.set(1,A,1),c.updateMatrix(),a.setMatrixAt(d,c.matrix),c.position.set(g,f+A+.2,C),c.rotation.set(Bt(),Bt()*6,Bt());let _=.8+Bt()*.5;c.scale.set(_,_*.7,_),c.updateMatrix(),o.setMatrixAt(d,c.matrix),o.setColorAt(d,h.set(ae.flowers[Math.floor(Bt()*ae.flowers.length)])),c.position.set(g+(Bt()-.5)*.6,f+.45,C+(Bt()-.5)*.6),c.rotation.set((Bt()-.5)*.8,Bt()*6,(Bt()-.5)*.8),c.scale.setScalar(.8+Bt()*.5),c.updateMatrix(),l.setMatrixAt(d,c.matrix)}}Xt.add(a,o,l)}for(let n of Kh){let t=n.hw*2,e=n.hh*2,i=new ln([new at(-t/2,0),new at(t/2,n.lift),new at(t/2,0)]),s=new si(i,{depth:e,bevelEnabled:!1});s.translate(0,0,-e/2);let r=jn(256,256,(h,d,u)=>{h.fillStyle=ae.kick[1],h.fillRect(0,0,d,u),h.fillStyle=ae.kick[0];for(let f=0;f<3;f++){let x=20+f*78;h.beginPath(),h.moveTo(x,30),h.lineTo(x+44,128),h.lineTo(x,226),h.lineTo(x+26,226),h.lineTo(x+70,128),h.lineTo(x+26,30),h.closePath(),h.fill()}h.strokeStyle="rgba(120,40,10,.6)",h.lineWidth=10,h.strokeRect(5,5,d-10,u-10)}),a=new Lt({color:new Ot(ae.kick[0]),roughness:.7}),o=new $(s,[a,a]);o.position.set(n.x,.03,n.y),o.rotation.y=-n.a,o.castShadow=o.receiveShadow=!0,Xt.add(o);let l=new $(new we(Math.hypot(t,n.lift),e),new Lt({map:r,roughness:.6}));l.rotation.order="ZXY",l.rotation.x=-Math.PI/2,l.rotation.z=Math.atan2(n.lift,t),l.position.set(0,n.lift/2+.04,0),l.receiveShadow=!0,o.add(l);let c=new $(new Ee(.6,.1,e),new Se({color:16777215}));c.position.set(t/2-.4,n.lift+.02,0),o.add(c)}var Xh=Ws.map(n=>ze.spinner(n)),A_=Mf({scene:Xt,cellAt:Ys,bx0:Hn,bx1:Qn,by0:En,by1:Bn,theme:ae,roughs:Vo,bedFlowers:!ui}),uc=new $(new oe(.18,.18,15,8),new Lt({color:15920868}));uc.position.set(de.x,7.5+Lr,de.y);uc.castShadow=!0;Xt.add(uc);var gu=new we(7.5,4.4,14,6),Wo=new $(gu,new Lt({side:Ce,roughness:.8,map:jn(256,150,(n,t,e)=>{n.fillStyle="#17171b",n.fillRect(0,0,t,e),n.fillStyle="#fff",n.font="bold 44px Fredoka, sans-serif",n.textAlign="center",n.fillText("PUTT",t/2,62),n.fillText("PARTY",t/2,112)})}));Wo.position.set(de.x+3.75,12.6+Lr,de.y);Wo.castShadow=!0;Xt.add(Wo);var R_=gu.attributes.position.array.slice(),C_=(()=>{let e=document.createElement("canvas");e.width=256,e.height=128;let i=e.getContext("2d"),s=i.createImageData(256,128),r=new Float32Array(256*128),a=[];for(let o=0;o<12;o++){let l=(o+.5)/12,c=Math.max(6,Math.round(26*Math.sin(l*Math.PI)));for(let h=0;h<c;h++)a.push([(h+o%2*.5)/c,l,.42/c])}for(let o=0;o<128;o++)for(let l=0;l<256;l++){let c=l/256,h=o/128,d=0;for(let[u,f,x]of a){if(Math.abs(f-h)>.06)continue;let M=Math.abs(u-c);M=Math.min(M,1-M);let m=Math.hypot(M*Math.sin(h*Math.PI)*2,f-h)/Math.max(.012,x*2*Math.sin(f*Math.PI));m<1&&(d=Math.min(d,-(1-m*m)))}r[o*256+l]=d}for(let o=0;o<128;o++)for(let l=0;l<256;l++){let c=r[o*256+(l+1)%256]-r[o*256+(l+256-1)%256],h=r[Math.min(127,o+1)*256+l]-r[Math.max(0,o-1)*256+l],d=(o*256+l)*4,u=-c*1.6,f=-h*1.6,x=1,M=Math.hypot(u,f,x);s.data[d]=(u/M*.5+.5)*255,s.data[d+1]=(f/M*.5+.5)*255,s.data[d+2]=(x/M*.5+.5)*255,s.data[d+3]=255}return i.putImageData(s,0,0),new Qe(e)})(),rp=n=>new ri({color:n,roughness:.42,clearcoat:1,clearcoatRoughness:.12,normalMap:C_,normalScale:new at(.7,.7),envMapIntensity:.9}),dc=new $(new ye(Zt,40,24),rp(16777215));dc.castShadow=!0;Xt.add(dc);var Nr=new $(dc.geometry,rp(16747066));Nr.castShadow=!0;Nr.visible=!1;Xt.add(Nr);var P_=[ze.shadow(lt.tee[0],lt.tee[1],Zt*.95),ze.shadow(lt.tee[0],lt.tee[1],Zt*.95)],ci=null,Jn=1,Kn=1,oc=0,Xo=0;function I_(){let n=Hi.getBoundingClientRect();Jn=Math.max(1,n.width),Kn=Math.max(1,n.height),oc=n.left,Xo=n.top}var Of=52*Math.PI/180;function qo(n,t,e){en.position.set(n,Math.sin(Of)*e,t+Math.cos(Of)*e),en.lookAt(n,0,t),en.updateMatrixWorld()}function Hf(n,t,e){let i=e,s=200;for(let r=0;r<8;r++){let a=40,o=1600;for(let h=0;h<30;h++){let d=(a+o)/2;qo(t,i,d);let u=!0;for(let f of n){let x=f.clone().project(en);if(Math.abs(x.x)>.97||x.y>.66||x.y<-.9){u=!1;break}}u?o=d:a=d}s=o,qo(t,i,s);let l=1,c=-1;for(let h of n){let d=h.clone().project(en);l=Math.min(l,d.y),c=Math.max(c,d.y)}i-=(l- -.86)*s*.3}return{tx:t,tz:i,dist:s}}var Ur=!!lt.long||Bn-En>(Qn-Hn)*2.1,ms=Math.min(Bn-En,(Qn-Hn)*1.55),op=En+ms/2,L_=Bn-ms/2,ap=n=>Math.max(op,Math.min(L_,n)),Li=null,tc=null,Ze=null,tu=ap(lt.tee[1]-ms*.1);function Jo(){I_();let n=Jn,t=Kn;Gi.setSize(n,t,!1),Hi.width=Math.round(n*devicePixelRatio),Hi.height=Math.round(t*devicePixelRatio),en.aspect=n/t,en.updateProjectionMatrix();let e=[];for(let d of[Hn,Qn])for(let u of[En,Bn])for(let f of[0,lt.wallH])e.push(new O(d,f,u));if(fn&&e.push(new O(fn.x+fn.w/2,39,fn.y+fn.h/2)),e.push(new O(de.x,15+Lr,de.y)),Li=Hf(e,Vs,$o),Xt.fog.near=Li.dist*1,Xt.fog.far=Li.dist*3.2,Ur){let d=op,u=[];for(let x of[Hn,Qn])for(let M of[d-ms/2,d+ms/2])for(let m of[0,lt.wallH+3])u.push(new O(x,m,M));let f=Hf(u,Vs,d);tc={tx:f.tx,dz:f.tz-d,dist:f.dist}}qo(Li.tx,Li.tz,Li.dist),ci&&Xt.remove(ci);let i=m_(lt.backdrop),s=lt.backdropAR||1152/532,r=150,a=new Se({map:i,transparent:!0,depthWrite:!1,fog:!1});i.onUpdate=null;let o=new we(r*s,r);o.translate(0,r/2-1,0),ci=new $(o,a),ci.position.set(Vs,0,En-18),ci.lookAt(en.position.x,0,en.position.z),ci.renderOrder=-1;for(let d=0;d<14&&(ci.updateMatrixWorld(),!(new O(0,r-1,0).applyMatrix4(ci.matrixWorld).project(en).y>1.05));d++)ci.scale.multiplyScalar(1.15);Xt.add(ci);let l=document.createElement("canvas");l.width=4,l.height=128;let c=l.getContext("2d"),h=c.createLinearGradient(0,0,0,128);h.addColorStop(0,"#fff"),h.addColorStop(.5,"#fff"),h.addColorStop(.8,"rgba(255,255,255,.35)"),h.addColorStop(1,"#000"),c.fillStyle=h,c.fillRect(0,0,4,128),a.alphaMap=new Qe(l),a.needsUpdate=!0,Ze?!Ur||!ki?Object.assign(Ze,Li):Object.assign(Ze,lp()):Ze={...Li},qo(Ze.tx,Ze.tz,Ze.dist)}function lp(){return!Ur||!ki?Li:{tx:tc.tx,tz:tu+tc.dz,dist:tc.dist}}function D_(n){if(!Ur||!Ze)return;let t=N_();if(t.state==="sink"||t.state==="done")return;if(ki&&(t.state==="roll"||t.state==="rest")){let s=ap(t.y-ms*.1);Math.abs(s-tu)>ms*.16&&(tu=s)}let e=lp(),i=Math.min(1,n*(Math.abs(e.dist-Ze.dist)>5?1.8:1.5));Ze.tx+=(e.tx-Ze.tx)*i,Ze.tz+=(e.tz-Ze.tz)*i,Ze.dist+=(e.dist-Ze.dist)*i,qo(Ze.tx,Ze.tz,Ze.dist)}var yt={x:lt.tee[0],y:lt.tee[1],vx:0,vy:0,z:0,state:"rest",restX:lt.tee[0],restY:lt.tee[1],coins:Zo,picked:0,penalty:0},di=0,_e=0,ki=!1,hs=!1,Fn=null,Vt={x:lt.tee[0],y:lt.tee[1],vx:0,vy:0,z:0,state:"idle",restX:lt.tee[0],restY:lt.tee[1],coins:Zo,picked:0,penalty:0,ai:!0},U_=(()=>{let n=null;try{n=new URLSearchParams(location.search).get("vs")}catch{}if(n){try{localStorage.setItem("pp_vs3d",n)}catch{}return n}try{return localStorage.getItem("pp_vs3d")||"solo"}catch{return"solo"}})(),Jt=Rr[U_]||null,eu=null,Ko=0,Xs="you",Mn=!1,Ui=!1,nu=!1,hi=null,zo=10,N_=()=>Jt&&(Xs==="ai"||hi==="ai")&&Vt.state!=="idle"&&!Vt.gone?Vt:yt,An=bf(lt.par),Yo=Jl.find(n=>n.id===lt.challenge&&n.ok(lt))||Jl.find(n=>n.ok(lt)&&!["bank","clean","dry","birdie","long"].includes(n.id))||Jl.find(n=>n.id==="bank"),qt=n=>document.getElementById(n);qt("hn").textContent=`Hole ${lt.n} \xB7 ${lt.name}`;qt("hp").textContent=lt.par;qt("ik").textContent=`HOLE ${lt.n} \xB7 PAR ${lt.par}`;qt("it").textContent=lt.name;qt("ii").textContent=lt.idea||"";var ls=(()=>{try{let n=JSON.parse(localStorage.getItem("pp_wallet"));if(n&&typeof n.coins=="number")return n}catch{}return{coins:0,owned:{ball:["classic"],trail:["warm"],flag:["classic"]},equip:{ball:"classic",trail:"warm",flag:"classic"},unlocked:{}}})(),iu=()=>{try{localStorage.setItem("pp_wallet",JSON.stringify(ls))}catch{}};qt("hc").textContent=ls.coins;var Nn=(()=>{try{let n=JSON.parse(localStorage.getItem("pp_round_w"+(lt.world||1)));if(n&&n.h)return n}catch{}return{h:{}}})(),cp=()=>{try{localStorage.setItem("pp_round_w"+(lt.world||1),JSON.stringify(Nn))}catch{}};(lt.n===1||lt.n===lt.roundStart)&&(Nn.h={},cp());var ac={};for(let n in lt.sounds)ac[n]=new Audio(lt.sounds[n]),ac[n].preload="auto";var Je=(n,t=.6,e=1)=>{let i=ac[n];if(i)try{let s=i.cloneNode();s.volume=Math.min(1,t),e!==1&&(s.preservesPitch=!1,s.webkitPreservesPitch=!1,s.playbackRate=e),s.play().catch(()=>{})}catch{}},os=n=>{try{navigator.vibrate&&navigator.vibrate(n)}catch{}},Ir=[],fi=(n,t,e=0)=>{let i=new O(n,e,t).project(en);return[(i.x+1)/2*Jn,(1-i.y)/2*Kn]},rs=(n,t,e,i,s=70,r=.6,a=5)=>{let[o,l]=fi(n,t,1);for(let c=0;c<e;c++){let h=Math.random()*6.283,d=s*(.3+Math.random());Ir.push({x:o,y:l,vx:Math.cos(h)*d,vy:Math.sin(h)*d-s*.4,g:160,life:r,t:0,col:i,size:a*(.6+Math.random()*.8)})}},Cr={hit(n,t,e,i,s){let r=Math.min(1,t/120);r<.05||(Je(s==="stump"?"thud1":["wood1","wood2","wood3"][Math.floor(Math.random()*3)],.25+r*.7),r>.2&&(os(12),rs(n.x-e*Zt,n.y-i*Zt,6,"rgba(240,232,210,",50,.45,4)))},splash(n){Je("thud1",.6),os(30),rs(n.x,n.y,26,"rgba(190,230,255,",110,.8,6),n===yt&&!le&&(An.wet++,ou())},burrow(n){Je("thud1",.5),rs(n.x,n.y,14,"rgba(150,110,70,",60,.6,6)},popout(n,t){Je("wood2",.6),os(15),rs(t?t.ox:No.x,t?t.oy:No.y,22,"rgba(160,120,80,",90,.8,7)},coin(n,t){if(n.m.visible=!1,n.by=t===Vt?"ai":"you",t===Vt){Je("coin2",.4,.8),rs(n.x,n.y,12,"rgba(255,214,70,",60,.5,5),n.star&&Zn(`${Jt.face} stole the star!`,!0);return}Je(Math.random()<.5?"coin1":"coin2",.7),os(10);let[e,i]=fi(n.x,n.y,2);lc(e,i)},sink(n){n===Vt&&Jt&&Zn(`${Jt.face} ${Jt.name} sinks it!`,!0),Je("gem1",.9),os(40),hp=_e;let[t,e]=fi(de.x,de.y,Lr);ec.push({x:t,y:e,t:0});for(let i=0;i<26;i++){let s=Math.random()*6.283,r=90+Math.random()*160;Ir.push({x:t,y:e,vx:Math.cos(s)*r,vy:Math.sin(s)*r*.6-120,g:260,life:1,t:0,col:"rgba(255,224,110,",size:3+Math.random()*3})}},boing(n,t){Je("wood2",.7,1.9),os(18),rs(t.x,t.y,10,"rgba(255,90,80,",80,.5,5),(n.ev.mush||0)===1&&Zn("Boing!",!0)},land(n){Je("thud1",.45),rs(n.x,n.y,10,"rgba(235,225,200,",60,.5,5)},jump(n){Je("wood1",.6,1.3),os(15),Zn("Bunny Hop!",!0)},boost(n,t){Je("coin2",.35,.7),rs(n.x,n.y,12,"rgba(255,214,70,",70,.5,5)}},hp=-9,ec=[],dn=[];function Zn(n,t){let e=qt("shot");e&&(e.textContent=n,e.className=t?"small":"",e.offsetWidth,e.classList.add("pop"),clearTimeout(Zn.t),Zn.t=setTimeout(()=>e.classList.remove("pop"),t?900:1500))}function F_(n,t,e){return n===1?"HOLE IN ONE!":t.jump?"Jump Shot!":t.pipe?"Pipe Dream!":t.door==="sail"?"Through the Mill!":t.door==="barn"?"Barn Burner!":t.mush?"Mushroom Magic!":(t.walls||0)>=2?"Double Bank!":t.walls?"Bank Shot!":e>45?"Long Bomb!":t.paddle?"Petal Pusher!":null}var nc=[],lc=(n,t)=>{let e=qt("hc").getBoundingClientRect();nc.push({x:n,y:t,tx:e.left+e.width/2,ty:e.top+e.height/2,t:0})};function su(){let n=["#ffcf3a","#ff6b6b","#4fc3f7","#7ed957","#ffffff","#c792ea"];for(let t=0;t<160;t++){let e=-Math.PI/2+(Math.random()-.5)*2.2,i=380+Math.random()*520;Ir.push({x:Jn/2+(Math.random()-.5)*80,y:Kn*.55,vx:Math.cos(e)*i,vy:Math.sin(e)*i,g:820,life:2.4,t:0,col:n[t%n.length],size:6+Math.random()*6,rect:!0,rot:Math.random()*6,vr:(Math.random()-.5)*14})}Je("fw1",.55),setTimeout(()=>Je("fw2",.45),260)}function cc(n,t,e){return[n[0]+(t[0]-n[0])*e|0,n[1]+(t[1]-n[1])*e|0,n[2]+(t[2]-n[2])*e|0]}function O_(n){return n=Math.max(0,Math.min(1,n)),n<.5?cc([46,204,96],[245,197,24],n/.5):cc([245,197,24],[226,59,46],(n-.5)/.5)}function qh(n,t,e,i,s,r,a,o,l,c,h,d){n.beginPath(),n.moveTo(t,e);for(let f=1;f<=12;f++){let x=f/12,M=x*o,m=.74+.26*Math.sin(h*14+f*1.9),p=Math.sin(h*10+x*6.5)*l*c*.34*x,S=l*c*(1-x*d)*m+p;n.lineTo(t+i*M+r*S,e+s*M+a*S)}n.lineTo(t+i*o*(1+.06*Math.sin(h*11)),e+s*o*(1+.06*Math.sin(h*11)));for(let f=12;f>=1;f--){let x=f/12,M=x*o,m=.74+.26*Math.sin(h*14+f*1.9+2.4),p=Math.sin(h*10+x*6.5+3.1)*l*c*.34*x,S=l*c*(1-x*d)*m+p;n.lineTo(t+i*M-r*S,e+s*M-a*S)}n.closePath()}function H_(n,t,e,i,s,r,a){let o=performance.now()/1e3,l=-s,c=i,h=O_(r),d=9+r*16;n.save(),n.shadowColor=`rgb(${h})`,n.shadowBlur=18+r*14,qh(n,t,e,i,s,l,c,a,d,1.18,o,.74),n.fillStyle=`rgba(${h},0.9)`,n.fill(),n.shadowBlur=0;let u=cc(h,[255,255,255],.42);qh(n,t,e,i,s,l,c,a,d,.62,o,.8),n.fillStyle=`rgba(${u},0.95)`,n.fill();let f=cc(h,[255,255,255],.72);qh(n,t,e,i,s,l,c,a,d,.3,o,.84),n.fillStyle=`rgba(${f},0.98)`,n.fill(),n.restore()}var B_=(n,t)=>{let e=new O(n/Jn*2-1,-(t/Kn)*2+1,.5).unproject(en).sub(en.position).normalize(),i=(Zt-en.position.y)/e.y;return[en.position.x+e.x*i,en.position.z+e.z*i]};Hi.addEventListener("pointerdown",n=>{up()&&(Hi.setPointerCapture(n.pointerId),Fn={sx:n.clientX-oc,sy:n.clientY-Xo,x:n.clientX-oc,y:n.clientY-Xo})});Hi.addEventListener("pointermove",n=>{Fn&&(Fn.x=n.clientX-oc,Fn.y=n.clientY-Xo)});Hi.addEventListener("pointerup",()=>{if(!Fn)return;let n=Fn;Fn=null;let t=n.sx-n.x,e=n.sy-n.y,i=Math.hypot(t,e),s=Math.min(Jn,Kn)*.42,r=Math.min(1,i/s);if(r<.1)return;let[a,o]=fi(yt.x,yt.y),[l,c]=B_(a+t/i*80,o+e/i*80),h=Math.hypot(l-yt.x,c-yt.y)||1;fp((l-yt.x)/h,(c-yt.y)/h,r)});var up=()=>le?le.live&&!le.shot&&yt.state==="rest":ki&&!hs&&Xs==="you"&&!hi&&!Mn&&yt.state==="rest";function dp(n,t,e,i){au=0,n.ev={},n.from=[n.x,n.y],n.vx=t*i*sc,n.vy=e*i*sc,n.restX=n.x,n.restY=n.y,n.state="roll",Je("thud1",.3+i*.5)}function fp(n,t,e){if(dp(yt,n,t,e),le){le.shot=!0;return}di++,hi="you",qt("hs").textContent=di+(yt.penalty||0),qt("hint").style.opacity=0,qs()}function pp(){let n=qt("opp");if(!n)return;let t=["solo","rookie","ace","oracle"];n.innerHTML=t.map(e=>{let i=Rr[e];return`<button data-k="${e}" class="${(Jt?Jt.key:"solo")===e?"sel":""}" style="${i?`--c:${i.col}`:""}"><b>${i?i.face:"\u26F3"}</b>${i?i.name:"Solo"}<small>${i?i.lvl:"Just you"}</small></button>`}).join(""),n.querySelectorAll("button").forEach(e=>e.onclick=()=>{let i=e.dataset.k;Jt=Rr[i]||null;try{localStorage.setItem("pp_vs3d",i)}catch{}Jt&&Nr.material.color.set(Jt.col),pp()})}pp();Jt&&Nr.material.color.set(Jt.col);qt("ich")&&(qt("ich").innerHTML=`<span>\u2605 Challenge</span>${kh(Yo,lt)}`);lt.boss&&qt("ik")&&(qt("ik").textContent=`BOSS HOLE \xB7 HOLE ${lt.n} \xB7 PAR ${lt.par}`);qt("go").onclick=()=>{qt("intro").classList.remove("show"),ki=!0,Jt&&(eu=wf(lt,du)),qs(),Object.values(ac).forEach(n=>{try{n.muted=!0,n.play().then(()=>{n.pause(),n.currentTime=0,n.muted=!1}).catch(()=>{n.muted=!1})}catch{}})};qt("again").onclick=()=>location.reload();lt.next?(qt("nexth").onclick=()=>mp(),lt.last&&(qt("nexth").textContent=/\.\.\/\.\.\/$/.test(lt.next)?"Finish round":"Back ten \u203A")):qt("nexth").style.display="none";var ru=n=>n.state==="rest"||n.state==="done"||n.state==="idle";function qs(){let n=qt("ros");if(!n)return;if(!Jt){n.style.display="none";return}n.style.display="";let t=di+(yt.penalty||0),e=Ko+(Vt.penalty||0);n.innerHTML=`<div class="${Xs==="you"&&!Mn?"on":""}"><i style="background:#fff"></i>You <b>${t}</b>${Mn?" \u2713":""}</div><div class="${Xs==="ai"&&!Ui?"on":""}" style="--c:${Jt.col}"><i style="background:${Jt.col}"></i>${Jt.face} ${Jt.name} <b>${e}</b>${Ui?" \u2713":""}</div>`}function zi(n,t=0){let e=qt("hint");e.textContent=n,e.style.opacity=1,clearTimeout(zi.t),t&&(zi.t=setTimeout(()=>{e.style.opacity=0},t))}function k_(){if(nu||!ru(yt)||!ru(Vt))return;hi==="you"&&(Tf(An,yt.ev||{}),yt.state==="done"&&!Mn&&(Mn=!0,An.fin=yt.ev||{},An.from=yt.from?Math.hypot(yt.from[0]-de.x,yt.from[1]-de.y):0)),hi==="ai"&&Vt.state==="done"&&(Ui=!0),hi==="you"&&Jt&&Vt.state==="done"&&(Ui=!0),hi==="ai"&&yt.state==="done"&&!Mn&&(Mn=!0,An.fin={},An.from=0),!Mn&&di+(yt.penalty||0)>=zo&&(Mn=!0,yt.gone=!0,zi("Picked up at "+zo,1500)),Jt&&!Ui&&Ko+(Vt.penalty||0)>=zo&&(Ui=!0,Vt.gone=!0);let n=hi;if(hi=null,!n&&ki){!Jt&&Mn&&!hs&&Bf();return}if(Mn&&(!Jt||Ui)){qs(),hs||Bf();return}Xs=Jt?n==="you"?Ui?"you":"ai":Mn?"ai":"you":"you",qs(),Xs==="ai"?z_():Jt&&zi("Your turn",1200)}async function z_(){if(nu=!0,zi(`${Jt.face} ${Jt.name} is lining up\u2026`),Vt.state==="idle"){if(Vt.x=lt.tee[0],Vt.y=lt.tee[1],Math.hypot(yt.x-Vt.x,yt.y-Vt.y)<2*Zt+.6)for(let[o,l]of[[3.4,0],[-3.4,0],[0,3.4],[0,-3.4]]){let c=lt.tee[0]+o,h=lt.tee[1]+l;if(Ys(c,h)===1&&Ni(c,h)>Zt+.4&&Math.hypot(yt.x-c,yt.y-h)>2*Zt+.6){Vt.x=c,Vt.y=h;break}}Vt.state="rest",Vt.restX=Vt.x,Vt.restY=Vt.y}let n=cs.length||Ws.length||Fi.length,t=as+Math.round((n?3.2:.5)/tn)*tn,e=performance.now(),i=yt.state==="rest"&&!yt.gone&&!Mn?[yt.x,yt.y]:null,s=await eu.plan(Vt.x,Vt.y,t,Jt,6,i),r=1e3*(Jt.think[0]+Math.random()*(Jt.think[1]-Jt.think[0]));for(;performance.now()-e<r;)await new Promise(o=>requestAnimationFrame(o));let a=eu.execute(s,Jt);as>t+1e-6?Vt.pending={e:a,t0:as}:Vt.pending={e:a,t0:t},await new Promise(o=>{Vt.onStrike=o}),Ko++,hi="ai",nu=!1,zi("",1),qs()}function G_(){if(!Jt)return;Zf(yt,Vt)>25&&(Je("wood1",.8,1.7),os(20),Zn("Knocked!",!0))}function ou(){let n=qt("mull");n&&(n.classList.add("show"),clearTimeout(ou.t),ou.t=setTimeout(()=>n.classList.remove("show"),4500),n.onclick=()=>{n.classList.remove("show"),Gh(t=>{t&&(di=Math.max(0,di-1),yt.penalty=Math.max(0,(yt.penalty||0)-1),An.wet=Math.max(0,An.wet-1),qt("hs").textContent=di+(yt.penalty||0),qs(),Zn("Mulligan!",!0))})})}var Yh=(()=>{try{return JSON.parse(localStorage.getItem("pp_stars3d"))||{}}catch{return{}}})();function Bf(){hs=!0;let n=Math.min(zo,di+(yt.penalty||0)),t=n-lt.par,e=yt.gone?"PICKED UP":n===1?"ACE!":t<=-2?"EAGLE!":t===-1?"BIRDIE!":t===0?"PAR":t===1?"BOGEY":"+"+t;An.total=n;let i=Zo.find(m=>m.star),s=[!yt.gone&&t<=0,i?i.by==="you":!yt.gone&&t<=0,!yt.gone&&Yo.done(An)],r=s.filter(Boolean).length,a=`w${lt.world||1}-${lt.n}`,o=Yh[a]||0;if(r>o){Yh[a]=r;try{localStorage.setItem("pp_stars3d",JSON.stringify(Yh))}catch{}}let l=(yt.gone?0:n===1?25:t<=-2?15:t===-1?10:t===0?5:t===1?2:1)+(yt.picked||0)+(s[2]?10:0),c="";if(Jt){let m=Math.min(zo,Ko+(Vt.penalty||0)),p=n<m,S=n===m;p&&(l+=Jt.bonus),c=`${Jt.face} ${Jt.name} ${m} \xB7 You ${n} \u2014 ${p?`you win the hole! +${Jt.bonus}`:S?"halved":`${Jt.name} takes it ${Jt.emote.good}`}`,Nn.ai=Nn.ai||{},Nn.ai[lt.n]=m,Nn.vs=Jt.key}ls.coins+=l,iu(),Nn.h[lt.n]=n,cp();let h=Object.keys(Nn.h).map(Number).sort((m,p)=>m-p),d=h.reduce((m,p)=>m+Nn.h[p],0),u=h.reduce((m,p)=>m+((lt.pars||{})[p]||0),0),f=d-u,x=h.length>1?` \xB7 round ${d} (${f>0?"+":f<0?"\u2212":"\xB1"}${Math.abs(f)})`:"";if(lt.last&&qt("rsc")){let m=Object.keys(lt.pars||{}).map(Number).sort((g,C)=>g-C),p=Nn.ai||{},S=Rr[Nn.vs],E=(g,C)=>`<tr><th>${g}</th>${m.map(A=>{let _=C[A],T=_-lt.pars[A];return`<td class="${_==null?"":T<0?"u":T>0?"o":""}">${_==null?"\u2013":_}</td>`}).join("")}</tr>`;qt("rsc").innerHTML=`<table><tr><th>Hole</th>${m.map(g=>`<td>${g}</td>`).join("")}</tr><tr><th>Par</th>${m.map(g=>`<td>${lt.pars[g]}</td>`).join("")}</tr>${E("You",Nn.h)}${S&&Object.keys(p).length?E(S.face,p):""}</table>`}let M=yt.gone?null:F_(n,An.fin||{},An.from||0);M&&Zn(M),yt.gone||(su(),r>=2&&setTimeout(su,450));for(let m=0;m<Math.min(12,l);m++)setTimeout(()=>{let[p,S]=fi(de.x,de.y,2);lc(p+(Math.random()-.5)*40,S),Je("coin1",.35)},300+m*90);setTimeout(()=>{qt("rt").textContent=e,qt("rs").innerHTML=[0,1,2].map(p=>`<span class="${s[p]?"":"off"}">\u2605</span>`).join(""),qt("rsg").innerHTML=[["Par",s[0]],["Gold star",s[1]],[kh(Yo,lt),s[2]]].map(([p,S])=>`<span class="${S?"ok":""}">${S?"\u2713":"\u25CB"} ${p}</span>`).join(""),qt("rp").innerHTML=`${n} shot${n>1?"s":""} \xB7 par ${lt.par} \xB7 +${l} coins${x}${c?`<br><b class="vs">${c}</b>`:""}`;let m=qt("dbl");m&&(m.style.display=l>0?"":"none",m.textContent=`\u25B6 Watch ad \xB7 double to +${l*2}`,m.onclick=()=>Gh(p=>{if(p){ls.coins+=l,iu(),qt("hc").textContent=ls.coins,m.style.display="none";for(let S=0;S<12;S++)setTimeout(()=>{lc(Jn/2+(Math.random()-.5)*60,Kn/2),Je("coin1",.35)},S*70)}})),qt("result").classList.add("show"),qt("hc").textContent=ls.coins},1300)}var le=null,V_=[];function W_(){let n=lt.tee[0],t=lt.tee[1],e=[];for(let i=En+4;i<Bn-4;i+=3)for(let s=Hn+4;s<Qn-4;s+=3){let r=Math.hypot(s-n,i-t);r<24||r>(Ur?ms*.8:75)||Ys(s,i)!==1||Ni(s,i)<6||Math.hypot(s-de.x,i-de.y)<12||Ur&&i>t||e.push([s,i,r])}for(let i=e.length-1;i>0;i--){let s=Math.floor(Math.random()*(i+1));[e[i],e[s]]=[e[s],e[i]]}for(let[i,s]of e.slice(0,40)){let r=Math.atan2(s-t,i-n);for(let a=.1;a<=1;a+=.04){let o=du(n,t,Math.cos(r),Math.sin(r),a,_e);if(!o.penalty&&!o.sunk&&Math.hypot(o.x-i,o.y-s)<1.6)return[i,s]}}return null}function mp(){qt("result").classList.remove("show");let n=W_();if(!n)return xu();le={x:n[0],y:n[1],live:!1,shot:!1,left:15},[[7.5,"#e2463a"],[4.6,"#fffdf5"],[2.2,"#ffcf3a"]].forEach(([t,e],i)=>{let s=new $(new yn(t,48),new Se({color:e,transparent:!0,opacity:.9,depthWrite:!1}));s.rotation.x=-Math.PI/2,s.position.set(le.x,Ue(le.x,le.y)+.06+i*.01,le.y),s.renderOrder=3,Xt.add(s),V_.push(s)}),Vt.gone=!0,yt.gone=!1,yt.state="rest",yt.x=lt.tee[0],yt.y=lt.tee[1],yt.z=0,yt.vx=yt.vy=0,yt.restX=yt.x,yt.restY=yt.y,yt.penalty=0,yt.air=!1,dn.length=0,qt("bonus").classList.add("show")}function gp(){qt("bonus").classList.remove("show"),le.live=!0,zi("Trick shot \xB7 15",0)}function kf(){if(!le||le.over)return;le.over=!0,le.live=!1;let n=Math.hypot(yt.x-le.x,yt.y-le.y),t=le.shot&&yt.state==="rest",e=t?n<2.2?25:n<4.6?10:n<7.5?5:0:0;if(e){ls.coins+=e,iu(),Zn(e===25?"BULLSEYE! +25":`+${e} coins`);for(let i=0;i<Math.min(12,e);i++)setTimeout(()=>{let[s,r]=fi(yt.x,yt.y,2);lc(s,r),Je("coin1",.35)},i*80);e===25&&su()}else Zn(le.shot?"So close!":"Time's up",!0);zi("",1),setTimeout(xu,e?1800:1200)}function xu(){Lf(()=>{location.href=lt.next})}qt("bgo")&&(qt("bgo").onclick=gp);qt("bskip")&&(qt("bskip").onclick=()=>{qt("bonus").classList.remove("show"),xu()});var zf=performance.now(),ic=1,au=0,jl=0,as=0;function xp(n){let t=Math.min(.03333333333333333,(n-zf)/1e3);zf=n;{let o=Vt.state==="roll"&&!Vt.gone?Vt:yt,l=Math.hypot(o.x-de.x,o.y-de.y),c=Math.hypot(o.vx,o.vy),h=c>1?((de.x-o.x)*o.vx+(de.y-o.y)*o.vy)/(l*c+1e-6):0,d=o.state==="roll"&&!o.air&&l<8&&l>Di*.6&&c>18&&c<75&&h>.55&&au<1;d&&(au+=t),ic+=((d?.5:1)-ic)*Math.min(1,t*8)}let e=t*ic;_e+=e;for(let o of Fi)cu(o,_e);for(D_(e),jl=Math.min(jl+e,.25);jl>=tn;){if(jl-=tn,ki&&!hs){if(Vt.pending&&as>=Vt.pending.t0-1e-6){let o=Vt.pending.e;Vt.pending=null,dp(Vt,o.dx,o.dy,o.pw),Vt.onStrike&&Vt.onStrike()}Fo(yt,tn,as,Cr),Oo(yt,tn,Cr),Jt&&(Fo(Vt,tn,as,Cr),Oo(Vt,tn,Cr),G_())}else le&&!le.over&&(le.live||le.shot)&&(Fo(yt,tn,as,Cr),Oo(yt,tn,Cr));as+=tn}if(ki&&!hs&&(k_(),qt("hs").textContent=di+(yt.penalty||0),Jt&&(Vt.state==="roll"||yt.state==="roll")&&qs()),le&&!le.over&&(le.live||le.shot))if(le.shot)ru(yt)&&kf();else{le.left-=t;let o=Math.ceil(le.left);o!==le.n&&(le.n=o,zi("Trick shot \xB7 "+Math.max(0,o))),le.left<=0&&kf()}for(let[o,l]of[[dc,yt],[Nr,Vt]]){o.visible=l.state!=="idle"&&!l.gone&&l.state!=="tunnel"&&!(l.state==="splash"&&l.timer<.6)&&(l===yt||!!Jt),o.position.set(l.x,Zt+(l.z||0)+(l.az||0)+(l.kick>=0&&l.kz||0)+Ue(l.x,l.y),l.y),l.state==="roll"&&(o.rotation.x+=l.vy*e/Zt,o.rotation.z-=l.vx*e/Zt);let c=P_[l===yt?0:1],h=(l.az||0)+(l.kick>=0&&l.kz||0);c.visible=o.visible&&(l.z||0)>-.5,c.position.set(l.x+.35,Ue(l.x,l.y)+.07,l.y+.25),c.scale.setScalar(1+h*.06),c.material.opacity=.85/(1+h*.18)}let i=(o,l)=>{let c=1e9;for(let h of[yt,Vt])h.state==="roll"&&!h.gone&&(c=Math.min(c,Math.hypot(h.x-o,h.y-l)));return c};if(Gs){Gs.rotation.z=Vf(_e);let o=lu(_e);ko.material.color.setHex(o?16730682:4259696),ko.material.emissive.setHex(o?13643807:3199056)}let s=o=>{let l=i(o.x,o.y);return l<7?Math.abs(Math.sin(_e*16))*.9*(1-l/7):0};Fi.forEach((o,l)=>{if(o.kind==="sheep"){let c=Wh[l],h=Math.cos(_e*o.sp+o.ph)>=0?1:-1;c.position.set(o.x,Math.abs(Math.sin(_e*6+l))*.25+Ue(o.x,o.y),o.y),c.rotation.y=o.axis==="y"?h>0?-Math.PI/2:Math.PI/2:h>0?0:Math.PI,c.position.y+=s(o);return}Wh[l].update(_e,o.x,o.y,Math.cos(_e*o.sp+o.ph)>=0?1:-1,l),Wh[l].g.position.y+=s(o)});for(let o of ip){let l=Xf(o.b,_e)?1.75:0;o.a+=(l-o.a)*Math.min(1,e*9),o.l.rotation.y=o.a,o.r.rotation.y=-o.a}for(let o of Zo)o.got||(o.m.rotation.y=_e*2.4,o.m.position.y=(o.h||0)+2+Math.sin(_e*3+o.x)*.35);{let o=_e-hp,l=o>=0&&o<1.6?Math.sin(Math.min(1,o/.35)*Math.PI/2)*4*(o<1.1?1:1-(o-1.1)/.5):0;uc.position.y=7.5+Lr+l,Wo.position.y=12.6+Lr+l,Wo.rotation.y=o>=0&&o<1.6?Math.sin(o*9)*.4:0}for(let o of Jt?[yt,Vt]:[yt])o.state==="roll"&&!o.gone&&Math.hypot(o.vx,o.vy)>35&&dn.push([o.x,o.y,(o.az||0)+(o.kick>=0&&o.kz||0)+Ue(o.x,o.y)+Zt,_e]);for(;dn.length&&(_e-dn[0][3]>.35||dn.length>28);)dn.shift();{let o=gu.attributes.position;for(let l=0;l<o.count;l++){let c=R_[l*3]+3.75;o.array[l*3+2]=Math.sin(_e*4.5-c*.9)*.45*(c/7.5)}o.needsUpdate=!0}Ws.forEach((o,l)=>{let c=uu(o,_e);Xh[l].arms.rotation.y=-c,Xh[l].head.rotation.y=Xh[l].spinHead?-c*.5:-c}),ze.update(_e),hu.forEach((o,l)=>{let c=_e-o.hitT,h=c>=0&&c<.5?Math.exp(-c*9)*Math.cos(c*40)*.28:0,d=i(o.x,o.y),u=.018*Math.sin(_e*2.2+l*1.3),f=d<10?.05*Math.sin(_e*24+l)*(1-d/10):0;w_[l].scale.set(1+h*.6-u*.5-f*.5,1-h+u+f,1+h*.6-u*.5-f*.5)});for(let o of b_)o.offset.x=-_e*1.4;for(let o of sp)o.opacity=.75+.25*Math.sin(_e*6);A_.update(_e);for(let o of ep)o.offset.x=_e*.04,o.offset.y=Math.sin(_e*.7)*.02;Gi.render(Xt,en);let r=p_,a=devicePixelRatio;if(r.setTransform(a,0,0,a,0,0),r.clearRect(0,0,Jn,Kn),dn.length>2){r.lineCap="round";for(let o=1;o<dn.length;o++){let l=fi(dn[o-1][0],dn[o-1][1],dn[o-1][2]),c=fi(dn[o][0],dn[o][1],dn[o][2]),h=o/dn.length;r.strokeStyle=`rgba(255,255,255,${.42*h})`,r.lineWidth=7*h,r.beginPath(),r.moveTo(l[0],l[1]),r.lineTo(c[0],c[1]),r.stroke()}}for(let o=ec.length-1;o>=0;o--){let l=ec[o];if(l.t+=t,l.t>.9){ec.splice(o,1);continue}let c=l.t/.9;r.strokeStyle=`rgba(255,220,100,${1-c})`,r.lineWidth=6*(1-c)+1,r.beginPath(),r.ellipse(l.x,l.y,10+c*90,(10+c*90)*.55,0,0,7),r.stroke()}if(Fn&&up()){let o=Fn.sx-Fn.x,l=Fn.sy-Fn.y,c=Math.hypot(o,l);if(c>6){let h=Math.min(Jn,Kn)*.42,d=Math.min(1,c/h),[u,f]=fi(yt.x,yt.y,Zt);H_(r,u,f,o/c,l/c,d,(.1+.2*d)*Math.min(Jn,Kn))}}for(let o=Ir.length-1;o>=0;o--){let l=Ir[o];if(l.t+=e,l.t>l.life){Ir.splice(o,1);continue}l.vy+=l.g*e,l.x+=l.vx*e,l.y+=l.vy*e;let c=1-l.t/l.life;l.rect?(l.rot+=l.vr*e,r.save(),r.translate(l.x,l.y),r.rotate(l.rot),r.fillStyle=l.col,r.globalAlpha=Math.min(1,c*1.5),r.fillRect(-l.size/2,-l.size/4,l.size,l.size/2),r.restore()):(r.fillStyle=l.col+.75*c+")",r.beginPath(),r.arc(l.x,l.y,l.size*(1+l.t),0,7),r.fill())}r.globalAlpha=1;for(let o=nc.length-1;o>=0;o--){let l=nc[o];if(l.t+=e/.7,l.t>=1){nc.splice(o,1);let u=qt("hc");u.textContent=ls.coins+(hs||le?0:yt.picked||0);continue}let c=l.t*l.t*(3-2*l.t),h=l.x+(l.tx-l.x)*c,d=l.y+(l.ty-l.y)*c-Math.sin(l.t*Math.PI)*80;r.fillStyle="#ffcf3a",r.strokeStyle="#b8860b",r.lineWidth=2,r.beginPath(),r.arc(h,d,9,0,7),r.fill(),r.stroke()}requestAnimationFrame(xp)}addEventListener("resize",Jo);addEventListener("orientationchange",()=>setTimeout(Jo,250));window.visualViewport&&visualViewport.addEventListener("resize",Jo);setInterval(()=>{let n=Hi.getBoundingClientRect();(Math.abs(n.width-Jn)>1||Math.abs(n.height-Kn)>1||Math.abs(n.top-Xo)>1)&&Jo()},500);Jo();requestAnimationFrame(xp);window.__g={timeScale:()=>ic,simulate:du,state:()=>({...yt,shots:di,started:ki,finished:hs,turn:Xs,rShots:Ko,youDone:Mn,rDone:Ui,R:{...Vt},bonus:le&&{...le}}),setOpp:n=>{Jt=Rr[n]||null},startBonus:mp,bonusGo:gp,HOLE:An,CH:()=>Yo&&Yo.id,start:()=>qt("go").onclick(),shoot:fp,D:lt,T:()=>_e,setT:n=>{_e=n},doorBlocked:lu,sd:Ni,cellAt:Ys,toScreen:fi};})();
/*! Bundled license information:

three/build/three.core.js:
three/build/three.module.js:
  (**
   * @license
   * Copyright 2010-2024 Three.js Authors
   * SPDX-License-Identifier: MIT
   *)
*/
