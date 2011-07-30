// BEGIN jquery-1.4.4.min.js
/*!
 * jQuery JavaScript Library v1.4.4
 * http://jquery.com/
 *
 * Copyright 2010, John Resig
 * Dual licensed under the MIT or GPL Version 2 licenses.
 * http://jquery.org/license
 *
 * Includes Sizzle.js
 * http://sizzlejs.com/
 * Copyright 2010, The Dojo Foundation
 * Released under the MIT, BSD, and GPL Licenses.
 *
 * Date: Thu Nov 11 19:04:53 2010 -0500
 */
(function(E,B){function ka(a,b,d){if(d===B&&a.nodeType===1){d=a.getAttribute("data-"+b);if(typeof d==="string"){try{d=d==="true"?true:d==="false"?false:d==="null"?null:!c.isNaN(d)?parseFloat(d):Ja.test(d)?c.parseJSON(d):d}catch(e){}c.data(a,b,d)}else d=B}return d}function U(){return false}function ca(){return true}function la(a,b,d){d[0].type=a;return c.event.handle.apply(b,d)}function Ka(a){var b,d,e,f,h,l,k,o,x,r,A,C=[];f=[];h=c.data(this,this.nodeType?"events":"__events__");if(typeof h==="function")h=
h.events;if(!(a.liveFired===this||!h||!h.live||a.button&&a.type==="click")){if(a.namespace)A=RegExp("(^|\\.)"+a.namespace.split(".").join("\\.(?:.*\\.)?")+"(\\.|$)");a.liveFired=this;var J=h.live.slice(0);for(k=0;k<J.length;k++){h=J[k];h.origType.replace(X,"")===a.type?f.push(h.selector):J.splice(k--,1)}f=c(a.target).closest(f,a.currentTarget);o=0;for(x=f.length;o<x;o++){r=f[o];for(k=0;k<J.length;k++){h=J[k];if(r.selector===h.selector&&(!A||A.test(h.namespace))){l=r.elem;e=null;if(h.preType==="mouseenter"||
h.preType==="mouseleave"){a.type=h.preType;e=c(a.relatedTarget).closest(h.selector)[0]}if(!e||e!==l)C.push({elem:l,handleObj:h,level:r.level})}}}o=0;for(x=C.length;o<x;o++){f=C[o];if(d&&f.level>d)break;a.currentTarget=f.elem;a.data=f.handleObj.data;a.handleObj=f.handleObj;A=f.handleObj.origHandler.apply(f.elem,arguments);if(A===false||a.isPropagationStopped()){d=f.level;if(A===false)b=false;if(a.isImmediatePropagationStopped())break}}return b}}function Y(a,b){return(a&&a!=="*"?a+".":"")+b.replace(La,
"`").replace(Ma,"&")}function ma(a,b,d){if(c.isFunction(b))return c.grep(a,function(f,h){return!!b.call(f,h,f)===d});else if(b.nodeType)return c.grep(a,function(f){return f===b===d});else if(typeof b==="string"){var e=c.grep(a,function(f){return f.nodeType===1});if(Na.test(b))return c.filter(b,e,!d);else b=c.filter(b,e)}return c.grep(a,function(f){return c.inArray(f,b)>=0===d})}function na(a,b){var d=0;b.each(function(){if(this.nodeName===(a[d]&&a[d].nodeName)){var e=c.data(a[d++]),f=c.data(this,
e);if(e=e&&e.events){delete f.handle;f.events={};for(var h in e)for(var l in e[h])c.event.add(this,h,e[h][l],e[h][l].data)}}})}function Oa(a,b){b.src?c.ajax({url:b.src,async:false,dataType:"script"}):c.globalEval(b.text||b.textContent||b.innerHTML||"");b.parentNode&&b.parentNode.removeChild(b)}function oa(a,b,d){var e=b==="width"?a.offsetWidth:a.offsetHeight;if(d==="border")return e;c.each(b==="width"?Pa:Qa,function(){d||(e-=parseFloat(c.css(a,"padding"+this))||0);if(d==="margin")e+=parseFloat(c.css(a,
"margin"+this))||0;else e-=parseFloat(c.css(a,"border"+this+"Width"))||0});return e}function da(a,b,d,e){if(c.isArray(b)&&b.length)c.each(b,function(f,h){d||Ra.test(a)?e(a,h):da(a+"["+(typeof h==="object"||c.isArray(h)?f:"")+"]",h,d,e)});else if(!d&&b!=null&&typeof b==="object")c.isEmptyObject(b)?e(a,""):c.each(b,function(f,h){da(a+"["+f+"]",h,d,e)});else e(a,b)}function S(a,b){var d={};c.each(pa.concat.apply([],pa.slice(0,b)),function(){d[this]=a});return d}function qa(a){if(!ea[a]){var b=c("<"+
a+">").appendTo("body"),d=b.css("display");b.remove();if(d==="none"||d==="")d="block";ea[a]=d}return ea[a]}function fa(a){return c.isWindow(a)?a:a.nodeType===9?a.defaultView||a.parentWindow:false}var t=E.document,c=function(){function a(){if(!b.isReady){try{t.documentElement.doScroll("left")}catch(j){setTimeout(a,1);return}b.ready()}}var b=function(j,s){return new b.fn.init(j,s)},d=E.jQuery,e=E.$,f,h=/^(?:[^<]*(<[\w\W]+>)[^>]*$|#([\w\-]+)$)/,l=/\S/,k=/^\s+/,o=/\s+$/,x=/\W/,r=/\d/,A=/^<(\w+)\s*\/?>(?:<\/\1>)?$/,
C=/^[\],:{}\s]*$/,J=/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g,w=/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,I=/(?:^|:|,)(?:\s*\[)+/g,L=/(webkit)[ \/]([\w.]+)/,g=/(opera)(?:.*version)?[ \/]([\w.]+)/,i=/(msie) ([\w.]+)/,n=/(mozilla)(?:.*? rv:([\w.]+))?/,m=navigator.userAgent,p=false,q=[],u,y=Object.prototype.toString,F=Object.prototype.hasOwnProperty,M=Array.prototype.push,N=Array.prototype.slice,O=String.prototype.trim,D=Array.prototype.indexOf,R={};b.fn=b.prototype={init:function(j,
s){var v,z,H;if(!j)return this;if(j.nodeType){this.context=this[0]=j;this.length=1;return this}if(j==="body"&&!s&&t.body){this.context=t;this[0]=t.body;this.selector="body";this.length=1;return this}if(typeof j==="string")if((v=h.exec(j))&&(v[1]||!s))if(v[1]){H=s?s.ownerDocument||s:t;if(z=A.exec(j))if(b.isPlainObject(s)){j=[t.createElement(z[1])];b.fn.attr.call(j,s,true)}else j=[H.createElement(z[1])];else{z=b.buildFragment([v[1]],[H]);j=(z.cacheable?z.fragment.cloneNode(true):z.fragment).childNodes}return b.merge(this,
j)}else{if((z=t.getElementById(v[2]))&&z.parentNode){if(z.id!==v[2])return f.find(j);this.length=1;this[0]=z}this.context=t;this.selector=j;return this}else if(!s&&!x.test(j)){this.selector=j;this.context=t;j=t.getElementsByTagName(j);return b.merge(this,j)}else return!s||s.jquery?(s||f).find(j):b(s).find(j);else if(b.isFunction(j))return f.ready(j);if(j.selector!==B){this.selector=j.selector;this.context=j.context}return b.makeArray(j,this)},selector:"",jquery:"1.4.4",length:0,size:function(){return this.length},
toArray:function(){return N.call(this,0)},get:function(j){return j==null?this.toArray():j<0?this.slice(j)[0]:this[j]},pushStack:function(j,s,v){var z=b();b.isArray(j)?M.apply(z,j):b.merge(z,j);z.prevObject=this;z.context=this.context;if(s==="find")z.selector=this.selector+(this.selector?" ":"")+v;else if(s)z.selector=this.selector+"."+s+"("+v+")";return z},each:function(j,s){return b.each(this,j,s)},ready:function(j){b.bindReady();if(b.isReady)j.call(t,b);else q&&q.push(j);return this},eq:function(j){return j===
-1?this.slice(j):this.slice(j,+j+1)},first:function(){return this.eq(0)},last:function(){return this.eq(-1)},slice:function(){return this.pushStack(N.apply(this,arguments),"slice",N.call(arguments).join(","))},map:function(j){return this.pushStack(b.map(this,function(s,v){return j.call(s,v,s)}))},end:function(){return this.prevObject||b(null)},push:M,sort:[].sort,splice:[].splice};b.fn.init.prototype=b.fn;b.extend=b.fn.extend=function(){var j,s,v,z,H,G=arguments[0]||{},K=1,Q=arguments.length,ga=false;
if(typeof G==="boolean"){ga=G;G=arguments[1]||{};K=2}if(typeof G!=="object"&&!b.isFunction(G))G={};if(Q===K){G=this;--K}for(;K<Q;K++)if((j=arguments[K])!=null)for(s in j){v=G[s];z=j[s];if(G!==z)if(ga&&z&&(b.isPlainObject(z)||(H=b.isArray(z)))){if(H){H=false;v=v&&b.isArray(v)?v:[]}else v=v&&b.isPlainObject(v)?v:{};G[s]=b.extend(ga,v,z)}else if(z!==B)G[s]=z}return G};b.extend({noConflict:function(j){E.$=e;if(j)E.jQuery=d;return b},isReady:false,readyWait:1,ready:function(j){j===true&&b.readyWait--;
if(!b.readyWait||j!==true&&!b.isReady){if(!t.body)return setTimeout(b.ready,1);b.isReady=true;if(!(j!==true&&--b.readyWait>0))if(q){var s=0,v=q;for(q=null;j=v[s++];)j.call(t,b);b.fn.trigger&&b(t).trigger("ready").unbind("ready")}}},bindReady:function(){if(!p){p=true;if(t.readyState==="complete")return setTimeout(b.ready,1);if(t.addEventListener){t.addEventListener("DOMContentLoaded",u,false);E.addEventListener("load",b.ready,false)}else if(t.attachEvent){t.attachEvent("onreadystatechange",u);E.attachEvent("onload",
b.ready);var j=false;try{j=E.frameElement==null}catch(s){}t.documentElement.doScroll&&j&&a()}}},isFunction:function(j){return b.type(j)==="function"},isArray:Array.isArray||function(j){return b.type(j)==="array"},isWindow:function(j){return j&&typeof j==="object"&&"setInterval"in j},isNaN:function(j){return j==null||!r.test(j)||isNaN(j)},type:function(j){return j==null?String(j):R[y.call(j)]||"object"},isPlainObject:function(j){if(!j||b.type(j)!=="object"||j.nodeType||b.isWindow(j))return false;if(j.constructor&&
!F.call(j,"constructor")&&!F.call(j.constructor.prototype,"isPrototypeOf"))return false;for(var s in j);return s===B||F.call(j,s)},isEmptyObject:function(j){for(var s in j)return false;return true},error:function(j){throw j;},parseJSON:function(j){if(typeof j!=="string"||!j)return null;j=b.trim(j);if(C.test(j.replace(J,"@").replace(w,"]").replace(I,"")))return E.JSON&&E.JSON.parse?E.JSON.parse(j):(new Function("return "+j))();else b.error("Invalid JSON: "+j)},noop:function(){},globalEval:function(j){if(j&&
l.test(j)){var s=t.getElementsByTagName("head")[0]||t.documentElement,v=t.createElement("script");v.type="text/javascript";if(b.support.scriptEval)v.appendChild(t.createTextNode(j));else v.text=j;s.insertBefore(v,s.firstChild);s.removeChild(v)}},nodeName:function(j,s){return j.nodeName&&j.nodeName.toUpperCase()===s.toUpperCase()},each:function(j,s,v){var z,H=0,G=j.length,K=G===B||b.isFunction(j);if(v)if(K)for(z in j){if(s.apply(j[z],v)===false)break}else for(;H<G;){if(s.apply(j[H++],v)===false)break}else if(K)for(z in j){if(s.call(j[z],
z,j[z])===false)break}else for(v=j[0];H<G&&s.call(v,H,v)!==false;v=j[++H]);return j},trim:O?function(j){return j==null?"":O.call(j)}:function(j){return j==null?"":j.toString().replace(k,"").replace(o,"")},makeArray:function(j,s){var v=s||[];if(j!=null){var z=b.type(j);j.length==null||z==="string"||z==="function"||z==="regexp"||b.isWindow(j)?M.call(v,j):b.merge(v,j)}return v},inArray:function(j,s){if(s.indexOf)return s.indexOf(j);for(var v=0,z=s.length;v<z;v++)if(s[v]===j)return v;return-1},merge:function(j,
s){var v=j.length,z=0;if(typeof s.length==="number")for(var H=s.length;z<H;z++)j[v++]=s[z];else for(;s[z]!==B;)j[v++]=s[z++];j.length=v;return j},grep:function(j,s,v){var z=[],H;v=!!v;for(var G=0,K=j.length;G<K;G++){H=!!s(j[G],G);v!==H&&z.push(j[G])}return z},map:function(j,s,v){for(var z=[],H,G=0,K=j.length;G<K;G++){H=s(j[G],G,v);if(H!=null)z[z.length]=H}return z.concat.apply([],z)},guid:1,proxy:function(j,s,v){if(arguments.length===2)if(typeof s==="string"){v=j;j=v[s];s=B}else if(s&&!b.isFunction(s)){v=
s;s=B}if(!s&&j)s=function(){return j.apply(v||this,arguments)};if(j)s.guid=j.guid=j.guid||s.guid||b.guid++;return s},access:function(j,s,v,z,H,G){var K=j.length;if(typeof s==="object"){for(var Q in s)b.access(j,Q,s[Q],z,H,v);return j}if(v!==B){z=!G&&z&&b.isFunction(v);for(Q=0;Q<K;Q++)H(j[Q],s,z?v.call(j[Q],Q,H(j[Q],s)):v,G);return j}return K?H(j[0],s):B},now:function(){return(new Date).getTime()},uaMatch:function(j){j=j.toLowerCase();j=L.exec(j)||g.exec(j)||i.exec(j)||j.indexOf("compatible")<0&&n.exec(j)||
[];return{browser:j[1]||"",version:j[2]||"0"}},browser:{}});b.each("Boolean Number String Function Array Date RegExp Object".split(" "),function(j,s){R["[object "+s+"]"]=s.toLowerCase()});m=b.uaMatch(m);if(m.browser){b.browser[m.browser]=true;b.browser.version=m.version}if(b.browser.webkit)b.browser.safari=true;if(D)b.inArray=function(j,s){return D.call(s,j)};if(!/\s/.test("\u00a0")){k=/^[\s\xA0]+/;o=/[\s\xA0]+$/}f=b(t);if(t.addEventListener)u=function(){t.removeEventListener("DOMContentLoaded",u,
false);b.ready()};else if(t.attachEvent)u=function(){if(t.readyState==="complete"){t.detachEvent("onreadystatechange",u);b.ready()}};return E.jQuery=E.$=b}();(function(){c.support={};var a=t.documentElement,b=t.createElement("script"),d=t.createElement("div"),e="script"+c.now();d.style.display="none";d.innerHTML="   <link/><table></table><a href='/a' style='color:red;float:left;opacity:.55;'>a</a><input type='checkbox'/>";var f=d.getElementsByTagName("*"),h=d.getElementsByTagName("a")[0],l=t.createElement("select"),
k=l.appendChild(t.createElement("option"));if(!(!f||!f.length||!h)){c.support={leadingWhitespace:d.firstChild.nodeType===3,tbody:!d.getElementsByTagName("tbody").length,htmlSerialize:!!d.getElementsByTagName("link").length,style:/red/.test(h.getAttribute("style")),hrefNormalized:h.getAttribute("href")==="/a",opacity:/^0.55$/.test(h.style.opacity),cssFloat:!!h.style.cssFloat,checkOn:d.getElementsByTagName("input")[0].value==="on",optSelected:k.selected,deleteExpando:true,optDisabled:false,checkClone:false,
scriptEval:false,noCloneEvent:true,boxModel:null,inlineBlockNeedsLayout:false,shrinkWrapBlocks:false,reliableHiddenOffsets:true};l.disabled=true;c.support.optDisabled=!k.disabled;b.type="text/javascript";try{b.appendChild(t.createTextNode("window."+e+"=1;"))}catch(o){}a.insertBefore(b,a.firstChild);if(E[e]){c.support.scriptEval=true;delete E[e]}try{delete b.test}catch(x){c.support.deleteExpando=false}a.removeChild(b);if(d.attachEvent&&d.fireEvent){d.attachEvent("onclick",function r(){c.support.noCloneEvent=
false;d.detachEvent("onclick",r)});d.cloneNode(true).fireEvent("onclick")}d=t.createElement("div");d.innerHTML="<input type='radio' name='radiotest' checked='checked'/>";a=t.createDocumentFragment();a.appendChild(d.firstChild);c.support.checkClone=a.cloneNode(true).cloneNode(true).lastChild.checked;c(function(){var r=t.createElement("div");r.style.width=r.style.paddingLeft="1px";t.body.appendChild(r);c.boxModel=c.support.boxModel=r.offsetWidth===2;if("zoom"in r.style){r.style.display="inline";r.style.zoom=
1;c.support.inlineBlockNeedsLayout=r.offsetWidth===2;r.style.display="";r.innerHTML="<div style='width:4px;'></div>";c.support.shrinkWrapBlocks=r.offsetWidth!==2}r.innerHTML="<table><tr><td style='padding:0;display:none'></td><td>t</td></tr></table>";var A=r.getElementsByTagName("td");c.support.reliableHiddenOffsets=A[0].offsetHeight===0;A[0].style.display="";A[1].style.display="none";c.support.reliableHiddenOffsets=c.support.reliableHiddenOffsets&&A[0].offsetHeight===0;r.innerHTML="";t.body.removeChild(r).style.display=
"none"});a=function(r){var A=t.createElement("div");r="on"+r;var C=r in A;if(!C){A.setAttribute(r,"return;");C=typeof A[r]==="function"}return C};c.support.submitBubbles=a("submit");c.support.changeBubbles=a("change");a=b=d=f=h=null}})();var ra={},Ja=/^(?:\{.*\}|\[.*\])$/;c.extend({cache:{},uuid:0,expando:"jQuery"+c.now(),noData:{embed:true,object:"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000",applet:true},data:function(a,b,d){if(c.acceptData(a)){a=a==E?ra:a;var e=a.nodeType,f=e?a[c.expando]:null,h=
c.cache;if(!(e&&!f&&typeof b==="string"&&d===B)){if(e)f||(a[c.expando]=f=++c.uuid);else h=a;if(typeof b==="object")if(e)h[f]=c.extend(h[f],b);else c.extend(h,b);else if(e&&!h[f])h[f]={};a=e?h[f]:h;if(d!==B)a[b]=d;return typeof b==="string"?a[b]:a}}},removeData:function(a,b){if(c.acceptData(a)){a=a==E?ra:a;var d=a.nodeType,e=d?a[c.expando]:a,f=c.cache,h=d?f[e]:e;if(b){if(h){delete h[b];d&&c.isEmptyObject(h)&&c.removeData(a)}}else if(d&&c.support.deleteExpando)delete a[c.expando];else if(a.removeAttribute)a.removeAttribute(c.expando);
else if(d)delete f[e];else for(var l in a)delete a[l]}},acceptData:function(a){if(a.nodeName){var b=c.noData[a.nodeName.toLowerCase()];if(b)return!(b===true||a.getAttribute("classid")!==b)}return true}});c.fn.extend({data:function(a,b){var d=null;if(typeof a==="undefined"){if(this.length){var e=this[0].attributes,f;d=c.data(this[0]);for(var h=0,l=e.length;h<l;h++){f=e[h].name;if(f.indexOf("data-")===0){f=f.substr(5);ka(this[0],f,d[f])}}}return d}else if(typeof a==="object")return this.each(function(){c.data(this,
a)});var k=a.split(".");k[1]=k[1]?"."+k[1]:"";if(b===B){d=this.triggerHandler("getData"+k[1]+"!",[k[0]]);if(d===B&&this.length){d=c.data(this[0],a);d=ka(this[0],a,d)}return d===B&&k[1]?this.data(k[0]):d}else return this.each(function(){var o=c(this),x=[k[0],b];o.triggerHandler("setData"+k[1]+"!",x);c.data(this,a,b);o.triggerHandler("changeData"+k[1]+"!",x)})},removeData:function(a){return this.each(function(){c.removeData(this,a)})}});c.extend({queue:function(a,b,d){if(a){b=(b||"fx")+"queue";var e=
c.data(a,b);if(!d)return e||[];if(!e||c.isArray(d))e=c.data(a,b,c.makeArray(d));else e.push(d);return e}},dequeue:function(a,b){b=b||"fx";var d=c.queue(a,b),e=d.shift();if(e==="inprogress")e=d.shift();if(e){b==="fx"&&d.unshift("inprogress");e.call(a,function(){c.dequeue(a,b)})}}});c.fn.extend({queue:function(a,b){if(typeof a!=="string"){b=a;a="fx"}if(b===B)return c.queue(this[0],a);return this.each(function(){var d=c.queue(this,a,b);a==="fx"&&d[0]!=="inprogress"&&c.dequeue(this,a)})},dequeue:function(a){return this.each(function(){c.dequeue(this,
a)})},delay:function(a,b){a=c.fx?c.fx.speeds[a]||a:a;b=b||"fx";return this.queue(b,function(){var d=this;setTimeout(function(){c.dequeue(d,b)},a)})},clearQueue:function(a){return this.queue(a||"fx",[])}});var sa=/[\n\t]/g,ha=/\s+/,Sa=/\r/g,Ta=/^(?:href|src|style)$/,Ua=/^(?:button|input)$/i,Va=/^(?:button|input|object|select|textarea)$/i,Wa=/^a(?:rea)?$/i,ta=/^(?:radio|checkbox)$/i;c.props={"for":"htmlFor","class":"className",readonly:"readOnly",maxlength:"maxLength",cellspacing:"cellSpacing",rowspan:"rowSpan",
colspan:"colSpan",tabindex:"tabIndex",usemap:"useMap",frameborder:"frameBorder"};c.fn.extend({attr:function(a,b){return c.access(this,a,b,true,c.attr)},removeAttr:function(a){return this.each(function(){c.attr(this,a,"");this.nodeType===1&&this.removeAttribute(a)})},addClass:function(a){if(c.isFunction(a))return this.each(function(x){var r=c(this);r.addClass(a.call(this,x,r.attr("class")))});if(a&&typeof a==="string")for(var b=(a||"").split(ha),d=0,e=this.length;d<e;d++){var f=this[d];if(f.nodeType===
1)if(f.className){for(var h=" "+f.className+" ",l=f.className,k=0,o=b.length;k<o;k++)if(h.indexOf(" "+b[k]+" ")<0)l+=" "+b[k];f.className=c.trim(l)}else f.className=a}return this},removeClass:function(a){if(c.isFunction(a))return this.each(function(o){var x=c(this);x.removeClass(a.call(this,o,x.attr("class")))});if(a&&typeof a==="string"||a===B)for(var b=(a||"").split(ha),d=0,e=this.length;d<e;d++){var f=this[d];if(f.nodeType===1&&f.className)if(a){for(var h=(" "+f.className+" ").replace(sa," "),
l=0,k=b.length;l<k;l++)h=h.replace(" "+b[l]+" "," ");f.className=c.trim(h)}else f.className=""}return this},toggleClass:function(a,b){var d=typeof a,e=typeof b==="boolean";if(c.isFunction(a))return this.each(function(f){var h=c(this);h.toggleClass(a.call(this,f,h.attr("class"),b),b)});return this.each(function(){if(d==="string")for(var f,h=0,l=c(this),k=b,o=a.split(ha);f=o[h++];){k=e?k:!l.hasClass(f);l[k?"addClass":"removeClass"](f)}else if(d==="undefined"||d==="boolean"){this.className&&c.data(this,
"__className__",this.className);this.className=this.className||a===false?"":c.data(this,"__className__")||""}})},hasClass:function(a){a=" "+a+" ";for(var b=0,d=this.length;b<d;b++)if((" "+this[b].className+" ").replace(sa," ").indexOf(a)>-1)return true;return false},val:function(a){if(!arguments.length){var b=this[0];if(b){if(c.nodeName(b,"option")){var d=b.attributes.value;return!d||d.specified?b.value:b.text}if(c.nodeName(b,"select")){var e=b.selectedIndex;d=[];var f=b.options;b=b.type==="select-one";
if(e<0)return null;var h=b?e:0;for(e=b?e+1:f.length;h<e;h++){var l=f[h];if(l.selected&&(c.support.optDisabled?!l.disabled:l.getAttribute("disabled")===null)&&(!l.parentNode.disabled||!c.nodeName(l.parentNode,"optgroup"))){a=c(l).val();if(b)return a;d.push(a)}}return d}if(ta.test(b.type)&&!c.support.checkOn)return b.getAttribute("value")===null?"on":b.value;return(b.value||"").replace(Sa,"")}return B}var k=c.isFunction(a);return this.each(function(o){var x=c(this),r=a;if(this.nodeType===1){if(k)r=
a.call(this,o,x.val());if(r==null)r="";else if(typeof r==="number")r+="";else if(c.isArray(r))r=c.map(r,function(C){return C==null?"":C+""});if(c.isArray(r)&&ta.test(this.type))this.checked=c.inArray(x.val(),r)>=0;else if(c.nodeName(this,"select")){var A=c.makeArray(r);c("option",this).each(function(){this.selected=c.inArray(c(this).val(),A)>=0});if(!A.length)this.selectedIndex=-1}else this.value=r}})}});c.extend({attrFn:{val:true,css:true,html:true,text:true,data:true,width:true,height:true,offset:true},
attr:function(a,b,d,e){if(!a||a.nodeType===3||a.nodeType===8)return B;if(e&&b in c.attrFn)return c(a)[b](d);e=a.nodeType!==1||!c.isXMLDoc(a);var f=d!==B;b=e&&c.props[b]||b;var h=Ta.test(b);if((b in a||a[b]!==B)&&e&&!h){if(f){b==="type"&&Ua.test(a.nodeName)&&a.parentNode&&c.error("type property can't be changed");if(d===null)a.nodeType===1&&a.removeAttribute(b);else a[b]=d}if(c.nodeName(a,"form")&&a.getAttributeNode(b))return a.getAttributeNode(b).nodeValue;if(b==="tabIndex")return(b=a.getAttributeNode("tabIndex"))&&
b.specified?b.value:Va.test(a.nodeName)||Wa.test(a.nodeName)&&a.href?0:B;return a[b]}if(!c.support.style&&e&&b==="style"){if(f)a.style.cssText=""+d;return a.style.cssText}f&&a.setAttribute(b,""+d);if(!a.attributes[b]&&a.hasAttribute&&!a.hasAttribute(b))return B;a=!c.support.hrefNormalized&&e&&h?a.getAttribute(b,2):a.getAttribute(b);return a===null?B:a}});var X=/\.(.*)$/,ia=/^(?:textarea|input|select)$/i,La=/\./g,Ma=/ /g,Xa=/[^\w\s.|`]/g,Ya=function(a){return a.replace(Xa,"\\$&")},ua={focusin:0,focusout:0};
c.event={add:function(a,b,d,e){if(!(a.nodeType===3||a.nodeType===8)){if(c.isWindow(a)&&a!==E&&!a.frameElement)a=E;if(d===false)d=U;else if(!d)return;var f,h;if(d.handler){f=d;d=f.handler}if(!d.guid)d.guid=c.guid++;if(h=c.data(a)){var l=a.nodeType?"events":"__events__",k=h[l],o=h.handle;if(typeof k==="function"){o=k.handle;k=k.events}else if(!k){a.nodeType||(h[l]=h=function(){});h.events=k={}}if(!o)h.handle=o=function(){return typeof c!=="undefined"&&!c.event.triggered?c.event.handle.apply(o.elem,
arguments):B};o.elem=a;b=b.split(" ");for(var x=0,r;l=b[x++];){h=f?c.extend({},f):{handler:d,data:e};if(l.indexOf(".")>-1){r=l.split(".");l=r.shift();h.namespace=r.slice(0).sort().join(".")}else{r=[];h.namespace=""}h.type=l;if(!h.guid)h.guid=d.guid;var A=k[l],C=c.event.special[l]||{};if(!A){A=k[l]=[];if(!C.setup||C.setup.call(a,e,r,o)===false)if(a.addEventListener)a.addEventListener(l,o,false);else a.attachEvent&&a.attachEvent("on"+l,o)}if(C.add){C.add.call(a,h);if(!h.handler.guid)h.handler.guid=
d.guid}A.push(h);c.event.global[l]=true}a=null}}},global:{},remove:function(a,b,d,e){if(!(a.nodeType===3||a.nodeType===8)){if(d===false)d=U;var f,h,l=0,k,o,x,r,A,C,J=a.nodeType?"events":"__events__",w=c.data(a),I=w&&w[J];if(w&&I){if(typeof I==="function"){w=I;I=I.events}if(b&&b.type){d=b.handler;b=b.type}if(!b||typeof b==="string"&&b.charAt(0)==="."){b=b||"";for(f in I)c.event.remove(a,f+b)}else{for(b=b.split(" ");f=b[l++];){r=f;k=f.indexOf(".")<0;o=[];if(!k){o=f.split(".");f=o.shift();x=RegExp("(^|\\.)"+
c.map(o.slice(0).sort(),Ya).join("\\.(?:.*\\.)?")+"(\\.|$)")}if(A=I[f])if(d){r=c.event.special[f]||{};for(h=e||0;h<A.length;h++){C=A[h];if(d.guid===C.guid){if(k||x.test(C.namespace)){e==null&&A.splice(h--,1);r.remove&&r.remove.call(a,C)}if(e!=null)break}}if(A.length===0||e!=null&&A.length===1){if(!r.teardown||r.teardown.call(a,o)===false)c.removeEvent(a,f,w.handle);delete I[f]}}else for(h=0;h<A.length;h++){C=A[h];if(k||x.test(C.namespace)){c.event.remove(a,r,C.handler,h);A.splice(h--,1)}}}if(c.isEmptyObject(I)){if(b=
w.handle)b.elem=null;delete w.events;delete w.handle;if(typeof w==="function")c.removeData(a,J);else c.isEmptyObject(w)&&c.removeData(a)}}}}},trigger:function(a,b,d,e){var f=a.type||a;if(!e){a=typeof a==="object"?a[c.expando]?a:c.extend(c.Event(f),a):c.Event(f);if(f.indexOf("!")>=0){a.type=f=f.slice(0,-1);a.exclusive=true}if(!d){a.stopPropagation();c.event.global[f]&&c.each(c.cache,function(){this.events&&this.events[f]&&c.event.trigger(a,b,this.handle.elem)})}if(!d||d.nodeType===3||d.nodeType===
8)return B;a.result=B;a.target=d;b=c.makeArray(b);b.unshift(a)}a.currentTarget=d;(e=d.nodeType?c.data(d,"handle"):(c.data(d,"__events__")||{}).handle)&&e.apply(d,b);e=d.parentNode||d.ownerDocument;try{if(!(d&&d.nodeName&&c.noData[d.nodeName.toLowerCase()]))if(d["on"+f]&&d["on"+f].apply(d,b)===false){a.result=false;a.preventDefault()}}catch(h){}if(!a.isPropagationStopped()&&e)c.event.trigger(a,b,e,true);else if(!a.isDefaultPrevented()){var l;e=a.target;var k=f.replace(X,""),o=c.nodeName(e,"a")&&k===
"click",x=c.event.special[k]||{};if((!x._default||x._default.call(d,a)===false)&&!o&&!(e&&e.nodeName&&c.noData[e.nodeName.toLowerCase()])){try{if(e[k]){if(l=e["on"+k])e["on"+k]=null;c.event.triggered=true;e[k]()}}catch(r){}if(l)e["on"+k]=l;c.event.triggered=false}}},handle:function(a){var b,d,e,f;d=[];var h=c.makeArray(arguments);a=h[0]=c.event.fix(a||E.event);a.currentTarget=this;b=a.type.indexOf(".")<0&&!a.exclusive;if(!b){e=a.type.split(".");a.type=e.shift();d=e.slice(0).sort();e=RegExp("(^|\\.)"+
d.join("\\.(?:.*\\.)?")+"(\\.|$)")}a.namespace=a.namespace||d.join(".");f=c.data(this,this.nodeType?"events":"__events__");if(typeof f==="function")f=f.events;d=(f||{})[a.type];if(f&&d){d=d.slice(0);f=0;for(var l=d.length;f<l;f++){var k=d[f];if(b||e.test(k.namespace)){a.handler=k.handler;a.data=k.data;a.handleObj=k;k=k.handler.apply(this,h);if(k!==B){a.result=k;if(k===false){a.preventDefault();a.stopPropagation()}}if(a.isImmediatePropagationStopped())break}}}return a.result},props:"altKey attrChange attrName bubbles button cancelable charCode clientX clientY ctrlKey currentTarget data detail eventPhase fromElement handler keyCode layerX layerY metaKey newValue offsetX offsetY pageX pageY prevValue relatedNode relatedTarget screenX screenY shiftKey srcElement target toElement view wheelDelta which".split(" "),
fix:function(a){if(a[c.expando])return a;var b=a;a=c.Event(b);for(var d=this.props.length,e;d;){e=this.props[--d];a[e]=b[e]}if(!a.target)a.target=a.srcElement||t;if(a.target.nodeType===3)a.target=a.target.parentNode;if(!a.relatedTarget&&a.fromElement)a.relatedTarget=a.fromElement===a.target?a.toElement:a.fromElement;if(a.pageX==null&&a.clientX!=null){b=t.documentElement;d=t.body;a.pageX=a.clientX+(b&&b.scrollLeft||d&&d.scrollLeft||0)-(b&&b.clientLeft||d&&d.clientLeft||0);a.pageY=a.clientY+(b&&b.scrollTop||
d&&d.scrollTop||0)-(b&&b.clientTop||d&&d.clientTop||0)}if(a.which==null&&(a.charCode!=null||a.keyCode!=null))a.which=a.charCode!=null?a.charCode:a.keyCode;if(!a.metaKey&&a.ctrlKey)a.metaKey=a.ctrlKey;if(!a.which&&a.button!==B)a.which=a.button&1?1:a.button&2?3:a.button&4?2:0;return a},guid:1E8,proxy:c.proxy,special:{ready:{setup:c.bindReady,teardown:c.noop},live:{add:function(a){c.event.add(this,Y(a.origType,a.selector),c.extend({},a,{handler:Ka,guid:a.handler.guid}))},remove:function(a){c.event.remove(this,
Y(a.origType,a.selector),a)}},beforeunload:{setup:function(a,b,d){if(c.isWindow(this))this.onbeforeunload=d},teardown:function(a,b){if(this.onbeforeunload===b)this.onbeforeunload=null}}}};c.removeEvent=t.removeEventListener?function(a,b,d){a.removeEventListener&&a.removeEventListener(b,d,false)}:function(a,b,d){a.detachEvent&&a.detachEvent("on"+b,d)};c.Event=function(a){if(!this.preventDefault)return new c.Event(a);if(a&&a.type){this.originalEvent=a;this.type=a.type}else this.type=a;this.timeStamp=
c.now();this[c.expando]=true};c.Event.prototype={preventDefault:function(){this.isDefaultPrevented=ca;var a=this.originalEvent;if(a)if(a.preventDefault)a.preventDefault();else a.returnValue=false},stopPropagation:function(){this.isPropagationStopped=ca;var a=this.originalEvent;if(a){a.stopPropagation&&a.stopPropagation();a.cancelBubble=true}},stopImmediatePropagation:function(){this.isImmediatePropagationStopped=ca;this.stopPropagation()},isDefaultPrevented:U,isPropagationStopped:U,isImmediatePropagationStopped:U};
var va=function(a){var b=a.relatedTarget;try{for(;b&&b!==this;)b=b.parentNode;if(b!==this){a.type=a.data;c.event.handle.apply(this,arguments)}}catch(d){}},wa=function(a){a.type=a.data;c.event.handle.apply(this,arguments)};c.each({mouseenter:"mouseover",mouseleave:"mouseout"},function(a,b){c.event.special[a]={setup:function(d){c.event.add(this,b,d&&d.selector?wa:va,a)},teardown:function(d){c.event.remove(this,b,d&&d.selector?wa:va)}}});if(!c.support.submitBubbles)c.event.special.submit={setup:function(){if(this.nodeName.toLowerCase()!==
"form"){c.event.add(this,"click.specialSubmit",function(a){var b=a.target,d=b.type;if((d==="submit"||d==="image")&&c(b).closest("form").length){a.liveFired=B;return la("submit",this,arguments)}});c.event.add(this,"keypress.specialSubmit",function(a){var b=a.target,d=b.type;if((d==="text"||d==="password")&&c(b).closest("form").length&&a.keyCode===13){a.liveFired=B;return la("submit",this,arguments)}})}else return false},teardown:function(){c.event.remove(this,".specialSubmit")}};if(!c.support.changeBubbles){var V,
xa=function(a){var b=a.type,d=a.value;if(b==="radio"||b==="checkbox")d=a.checked;else if(b==="select-multiple")d=a.selectedIndex>-1?c.map(a.options,function(e){return e.selected}).join("-"):"";else if(a.nodeName.toLowerCase()==="select")d=a.selectedIndex;return d},Z=function(a,b){var d=a.target,e,f;if(!(!ia.test(d.nodeName)||d.readOnly)){e=c.data(d,"_change_data");f=xa(d);if(a.type!=="focusout"||d.type!=="radio")c.data(d,"_change_data",f);if(!(e===B||f===e))if(e!=null||f){a.type="change";a.liveFired=
B;return c.event.trigger(a,b,d)}}};c.event.special.change={filters:{focusout:Z,beforedeactivate:Z,click:function(a){var b=a.target,d=b.type;if(d==="radio"||d==="checkbox"||b.nodeName.toLowerCase()==="select")return Z.call(this,a)},keydown:function(a){var b=a.target,d=b.type;if(a.keyCode===13&&b.nodeName.toLowerCase()!=="textarea"||a.keyCode===32&&(d==="checkbox"||d==="radio")||d==="select-multiple")return Z.call(this,a)},beforeactivate:function(a){a=a.target;c.data(a,"_change_data",xa(a))}},setup:function(){if(this.type===
"file")return false;for(var a in V)c.event.add(this,a+".specialChange",V[a]);return ia.test(this.nodeName)},teardown:function(){c.event.remove(this,".specialChange");return ia.test(this.nodeName)}};V=c.event.special.change.filters;V.focus=V.beforeactivate}t.addEventListener&&c.each({focus:"focusin",blur:"focusout"},function(a,b){function d(e){e=c.event.fix(e);e.type=b;return c.event.trigger(e,null,e.target)}c.event.special[b]={setup:function(){ua[b]++===0&&t.addEventListener(a,d,true)},teardown:function(){--ua[b]===
0&&t.removeEventListener(a,d,true)}}});c.each(["bind","one"],function(a,b){c.fn[b]=function(d,e,f){if(typeof d==="object"){for(var h in d)this[b](h,e,d[h],f);return this}if(c.isFunction(e)||e===false){f=e;e=B}var l=b==="one"?c.proxy(f,function(o){c(this).unbind(o,l);return f.apply(this,arguments)}):f;if(d==="unload"&&b!=="one")this.one(d,e,f);else{h=0;for(var k=this.length;h<k;h++)c.event.add(this[h],d,l,e)}return this}});c.fn.extend({unbind:function(a,b){if(typeof a==="object"&&!a.preventDefault)for(var d in a)this.unbind(d,
a[d]);else{d=0;for(var e=this.length;d<e;d++)c.event.remove(this[d],a,b)}return this},delegate:function(a,b,d,e){return this.live(b,d,e,a)},undelegate:function(a,b,d){return arguments.length===0?this.unbind("live"):this.die(b,null,d,a)},trigger:function(a,b){return this.each(function(){c.event.trigger(a,b,this)})},triggerHandler:function(a,b){if(this[0]){var d=c.Event(a);d.preventDefault();d.stopPropagation();c.event.trigger(d,b,this[0]);return d.result}},toggle:function(a){for(var b=arguments,d=
1;d<b.length;)c.proxy(a,b[d++]);return this.click(c.proxy(a,function(e){var f=(c.data(this,"lastToggle"+a.guid)||0)%d;c.data(this,"lastToggle"+a.guid,f+1);e.preventDefault();return b[f].apply(this,arguments)||false}))},hover:function(a,b){return this.mouseenter(a).mouseleave(b||a)}});var ya={focus:"focusin",blur:"focusout",mouseenter:"mouseover",mouseleave:"mouseout"};c.each(["live","die"],function(a,b){c.fn[b]=function(d,e,f,h){var l,k=0,o,x,r=h||this.selector;h=h?this:c(this.context);if(typeof d===
"object"&&!d.preventDefault){for(l in d)h[b](l,e,d[l],r);return this}if(c.isFunction(e)){f=e;e=B}for(d=(d||"").split(" ");(l=d[k++])!=null;){o=X.exec(l);x="";if(o){x=o[0];l=l.replace(X,"")}if(l==="hover")d.push("mouseenter"+x,"mouseleave"+x);else{o=l;if(l==="focus"||l==="blur"){d.push(ya[l]+x);l+=x}else l=(ya[l]||l)+x;if(b==="live"){x=0;for(var A=h.length;x<A;x++)c.event.add(h[x],"live."+Y(l,r),{data:e,selector:r,handler:f,origType:l,origHandler:f,preType:o})}else h.unbind("live."+Y(l,r),f)}}return this}});
c.each("blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error".split(" "),function(a,b){c.fn[b]=function(d,e){if(e==null){e=d;d=null}return arguments.length>0?this.bind(b,d,e):this.trigger(b)};if(c.attrFn)c.attrFn[b]=true});E.attachEvent&&!E.addEventListener&&c(E).bind("unload",function(){for(var a in c.cache)if(c.cache[a].handle)try{c.event.remove(c.cache[a].handle.elem)}catch(b){}});
(function(){function a(g,i,n,m,p,q){p=0;for(var u=m.length;p<u;p++){var y=m[p];if(y){var F=false;for(y=y[g];y;){if(y.sizcache===n){F=m[y.sizset];break}if(y.nodeType===1&&!q){y.sizcache=n;y.sizset=p}if(y.nodeName.toLowerCase()===i){F=y;break}y=y[g]}m[p]=F}}}function b(g,i,n,m,p,q){p=0;for(var u=m.length;p<u;p++){var y=m[p];if(y){var F=false;for(y=y[g];y;){if(y.sizcache===n){F=m[y.sizset];break}if(y.nodeType===1){if(!q){y.sizcache=n;y.sizset=p}if(typeof i!=="string"){if(y===i){F=true;break}}else if(k.filter(i,
[y]).length>0){F=y;break}}y=y[g]}m[p]=F}}}var d=/((?:\((?:\([^()]+\)|[^()]+)+\)|\[(?:\[[^\[\]]*\]|['"][^'"]*['"]|[^\[\]'"]+)+\]|\\.|[^ >+~,(\[\\]+)+|[>+~])(\s*,\s*)?((?:.|\r|\n)*)/g,e=0,f=Object.prototype.toString,h=false,l=true;[0,0].sort(function(){l=false;return 0});var k=function(g,i,n,m){n=n||[];var p=i=i||t;if(i.nodeType!==1&&i.nodeType!==9)return[];if(!g||typeof g!=="string")return n;var q,u,y,F,M,N=true,O=k.isXML(i),D=[],R=g;do{d.exec("");if(q=d.exec(R)){R=q[3];D.push(q[1]);if(q[2]){F=q[3];
break}}}while(q);if(D.length>1&&x.exec(g))if(D.length===2&&o.relative[D[0]])u=L(D[0]+D[1],i);else for(u=o.relative[D[0]]?[i]:k(D.shift(),i);D.length;){g=D.shift();if(o.relative[g])g+=D.shift();u=L(g,u)}else{if(!m&&D.length>1&&i.nodeType===9&&!O&&o.match.ID.test(D[0])&&!o.match.ID.test(D[D.length-1])){q=k.find(D.shift(),i,O);i=q.expr?k.filter(q.expr,q.set)[0]:q.set[0]}if(i){q=m?{expr:D.pop(),set:C(m)}:k.find(D.pop(),D.length===1&&(D[0]==="~"||D[0]==="+")&&i.parentNode?i.parentNode:i,O);u=q.expr?k.filter(q.expr,
q.set):q.set;if(D.length>0)y=C(u);else N=false;for(;D.length;){q=M=D.pop();if(o.relative[M])q=D.pop();else M="";if(q==null)q=i;o.relative[M](y,q,O)}}else y=[]}y||(y=u);y||k.error(M||g);if(f.call(y)==="[object Array]")if(N)if(i&&i.nodeType===1)for(g=0;y[g]!=null;g++){if(y[g]&&(y[g]===true||y[g].nodeType===1&&k.contains(i,y[g])))n.push(u[g])}else for(g=0;y[g]!=null;g++)y[g]&&y[g].nodeType===1&&n.push(u[g]);else n.push.apply(n,y);else C(y,n);if(F){k(F,p,n,m);k.uniqueSort(n)}return n};k.uniqueSort=function(g){if(w){h=
l;g.sort(w);if(h)for(var i=1;i<g.length;i++)g[i]===g[i-1]&&g.splice(i--,1)}return g};k.matches=function(g,i){return k(g,null,null,i)};k.matchesSelector=function(g,i){return k(i,null,null,[g]).length>0};k.find=function(g,i,n){var m;if(!g)return[];for(var p=0,q=o.order.length;p<q;p++){var u,y=o.order[p];if(u=o.leftMatch[y].exec(g)){var F=u[1];u.splice(1,1);if(F.substr(F.length-1)!=="\\"){u[1]=(u[1]||"").replace(/\\/g,"");m=o.find[y](u,i,n);if(m!=null){g=g.replace(o.match[y],"");break}}}}m||(m=i.getElementsByTagName("*"));
return{set:m,expr:g}};k.filter=function(g,i,n,m){for(var p,q,u=g,y=[],F=i,M=i&&i[0]&&k.isXML(i[0]);g&&i.length;){for(var N in o.filter)if((p=o.leftMatch[N].exec(g))!=null&&p[2]){var O,D,R=o.filter[N];D=p[1];q=false;p.splice(1,1);if(D.substr(D.length-1)!=="\\"){if(F===y)y=[];if(o.preFilter[N])if(p=o.preFilter[N](p,F,n,y,m,M)){if(p===true)continue}else q=O=true;if(p)for(var j=0;(D=F[j])!=null;j++)if(D){O=R(D,p,j,F);var s=m^!!O;if(n&&O!=null)if(s)q=true;else F[j]=false;else if(s){y.push(D);q=true}}if(O!==
B){n||(F=y);g=g.replace(o.match[N],"");if(!q)return[];break}}}if(g===u)if(q==null)k.error(g);else break;u=g}return F};k.error=function(g){throw"Syntax error, unrecognized expression: "+g;};var o=k.selectors={order:["ID","NAME","TAG"],match:{ID:/#((?:[\w\u00c0-\uFFFF\-]|\\.)+)/,CLASS:/\.((?:[\w\u00c0-\uFFFF\-]|\\.)+)/,NAME:/\[name=['"]*((?:[\w\u00c0-\uFFFF\-]|\\.)+)['"]*\]/,ATTR:/\[\s*((?:[\w\u00c0-\uFFFF\-]|\\.)+)\s*(?:(\S?=)\s*(['"]*)(.*?)\3|)\s*\]/,TAG:/^((?:[\w\u00c0-\uFFFF\*\-]|\\.)+)/,CHILD:/:(only|nth|last|first)-child(?:\((even|odd|[\dn+\-]*)\))?/,
POS:/:(nth|eq|gt|lt|first|last|even|odd)(?:\((\d*)\))?(?=[^\-]|$)/,PSEUDO:/:((?:[\w\u00c0-\uFFFF\-]|\\.)+)(?:\((['"]?)((?:\([^\)]+\)|[^\(\)]*)+)\2\))?/},leftMatch:{},attrMap:{"class":"className","for":"htmlFor"},attrHandle:{href:function(g){return g.getAttribute("href")}},relative:{"+":function(g,i){var n=typeof i==="string",m=n&&!/\W/.test(i);n=n&&!m;if(m)i=i.toLowerCase();m=0;for(var p=g.length,q;m<p;m++)if(q=g[m]){for(;(q=q.previousSibling)&&q.nodeType!==1;);g[m]=n||q&&q.nodeName.toLowerCase()===
i?q||false:q===i}n&&k.filter(i,g,true)},">":function(g,i){var n,m=typeof i==="string",p=0,q=g.length;if(m&&!/\W/.test(i))for(i=i.toLowerCase();p<q;p++){if(n=g[p]){n=n.parentNode;g[p]=n.nodeName.toLowerCase()===i?n:false}}else{for(;p<q;p++)if(n=g[p])g[p]=m?n.parentNode:n.parentNode===i;m&&k.filter(i,g,true)}},"":function(g,i,n){var m,p=e++,q=b;if(typeof i==="string"&&!/\W/.test(i)){m=i=i.toLowerCase();q=a}q("parentNode",i,p,g,m,n)},"~":function(g,i,n){var m,p=e++,q=b;if(typeof i==="string"&&!/\W/.test(i)){m=
i=i.toLowerCase();q=a}q("previousSibling",i,p,g,m,n)}},find:{ID:function(g,i,n){if(typeof i.getElementById!=="undefined"&&!n)return(g=i.getElementById(g[1]))&&g.parentNode?[g]:[]},NAME:function(g,i){if(typeof i.getElementsByName!=="undefined"){for(var n=[],m=i.getElementsByName(g[1]),p=0,q=m.length;p<q;p++)m[p].getAttribute("name")===g[1]&&n.push(m[p]);return n.length===0?null:n}},TAG:function(g,i){return i.getElementsByTagName(g[1])}},preFilter:{CLASS:function(g,i,n,m,p,q){g=" "+g[1].replace(/\\/g,
"")+" ";if(q)return g;q=0;for(var u;(u=i[q])!=null;q++)if(u)if(p^(u.className&&(" "+u.className+" ").replace(/[\t\n]/g," ").indexOf(g)>=0))n||m.push(u);else if(n)i[q]=false;return false},ID:function(g){return g[1].replace(/\\/g,"")},TAG:function(g){return g[1].toLowerCase()},CHILD:function(g){if(g[1]==="nth"){var i=/(-?)(\d*)n((?:\+|-)?\d*)/.exec(g[2]==="even"&&"2n"||g[2]==="odd"&&"2n+1"||!/\D/.test(g[2])&&"0n+"+g[2]||g[2]);g[2]=i[1]+(i[2]||1)-0;g[3]=i[3]-0}g[0]=e++;return g},ATTR:function(g,i,n,
m,p,q){i=g[1].replace(/\\/g,"");if(!q&&o.attrMap[i])g[1]=o.attrMap[i];if(g[2]==="~=")g[4]=" "+g[4]+" ";return g},PSEUDO:function(g,i,n,m,p){if(g[1]==="not")if((d.exec(g[3])||"").length>1||/^\w/.test(g[3]))g[3]=k(g[3],null,null,i);else{g=k.filter(g[3],i,n,true^p);n||m.push.apply(m,g);return false}else if(o.match.POS.test(g[0])||o.match.CHILD.test(g[0]))return true;return g},POS:function(g){g.unshift(true);return g}},filters:{enabled:function(g){return g.disabled===false&&g.type!=="hidden"},disabled:function(g){return g.disabled===
true},checked:function(g){return g.checked===true},selected:function(g){return g.selected===true},parent:function(g){return!!g.firstChild},empty:function(g){return!g.firstChild},has:function(g,i,n){return!!k(n[3],g).length},header:function(g){return/h\d/i.test(g.nodeName)},text:function(g){return"text"===g.type},radio:function(g){return"radio"===g.type},checkbox:function(g){return"checkbox"===g.type},file:function(g){return"file"===g.type},password:function(g){return"password"===g.type},submit:function(g){return"submit"===
g.type},image:function(g){return"image"===g.type},reset:function(g){return"reset"===g.type},button:function(g){return"button"===g.type||g.nodeName.toLowerCase()==="button"},input:function(g){return/input|select|textarea|button/i.test(g.nodeName)}},setFilters:{first:function(g,i){return i===0},last:function(g,i,n,m){return i===m.length-1},even:function(g,i){return i%2===0},odd:function(g,i){return i%2===1},lt:function(g,i,n){return i<n[3]-0},gt:function(g,i,n){return i>n[3]-0},nth:function(g,i,n){return n[3]-
0===i},eq:function(g,i,n){return n[3]-0===i}},filter:{PSEUDO:function(g,i,n,m){var p=i[1],q=o.filters[p];if(q)return q(g,n,i,m);else if(p==="contains")return(g.textContent||g.innerText||k.getText([g])||"").indexOf(i[3])>=0;else if(p==="not"){i=i[3];n=0;for(m=i.length;n<m;n++)if(i[n]===g)return false;return true}else k.error("Syntax error, unrecognized expression: "+p)},CHILD:function(g,i){var n=i[1],m=g;switch(n){case "only":case "first":for(;m=m.previousSibling;)if(m.nodeType===1)return false;if(n===
"first")return true;m=g;case "last":for(;m=m.nextSibling;)if(m.nodeType===1)return false;return true;case "nth":n=i[2];var p=i[3];if(n===1&&p===0)return true;var q=i[0],u=g.parentNode;if(u&&(u.sizcache!==q||!g.nodeIndex)){var y=0;for(m=u.firstChild;m;m=m.nextSibling)if(m.nodeType===1)m.nodeIndex=++y;u.sizcache=q}m=g.nodeIndex-p;return n===0?m===0:m%n===0&&m/n>=0}},ID:function(g,i){return g.nodeType===1&&g.getAttribute("id")===i},TAG:function(g,i){return i==="*"&&g.nodeType===1||g.nodeName.toLowerCase()===
i},CLASS:function(g,i){return(" "+(g.className||g.getAttribute("class"))+" ").indexOf(i)>-1},ATTR:function(g,i){var n=i[1];n=o.attrHandle[n]?o.attrHandle[n](g):g[n]!=null?g[n]:g.getAttribute(n);var m=n+"",p=i[2],q=i[4];return n==null?p==="!=":p==="="?m===q:p==="*="?m.indexOf(q)>=0:p==="~="?(" "+m+" ").indexOf(q)>=0:!q?m&&n!==false:p==="!="?m!==q:p==="^="?m.indexOf(q)===0:p==="$="?m.substr(m.length-q.length)===q:p==="|="?m===q||m.substr(0,q.length+1)===q+"-":false},POS:function(g,i,n,m){var p=o.setFilters[i[2]];
if(p)return p(g,n,i,m)}}},x=o.match.POS,r=function(g,i){return"\\"+(i-0+1)},A;for(A in o.match){o.match[A]=RegExp(o.match[A].source+/(?![^\[]*\])(?![^\(]*\))/.source);o.leftMatch[A]=RegExp(/(^(?:.|\r|\n)*?)/.source+o.match[A].source.replace(/\\(\d+)/g,r))}var C=function(g,i){g=Array.prototype.slice.call(g,0);if(i){i.push.apply(i,g);return i}return g};try{Array.prototype.slice.call(t.documentElement.childNodes,0)}catch(J){C=function(g,i){var n=0,m=i||[];if(f.call(g)==="[object Array]")Array.prototype.push.apply(m,
g);else if(typeof g.length==="number")for(var p=g.length;n<p;n++)m.push(g[n]);else for(;g[n];n++)m.push(g[n]);return m}}var w,I;if(t.documentElement.compareDocumentPosition)w=function(g,i){if(g===i){h=true;return 0}if(!g.compareDocumentPosition||!i.compareDocumentPosition)return g.compareDocumentPosition?-1:1;return g.compareDocumentPosition(i)&4?-1:1};else{w=function(g,i){var n,m,p=[],q=[];n=g.parentNode;m=i.parentNode;var u=n;if(g===i){h=true;return 0}else if(n===m)return I(g,i);else if(n){if(!m)return 1}else return-1;
for(;u;){p.unshift(u);u=u.parentNode}for(u=m;u;){q.unshift(u);u=u.parentNode}n=p.length;m=q.length;for(u=0;u<n&&u<m;u++)if(p[u]!==q[u])return I(p[u],q[u]);return u===n?I(g,q[u],-1):I(p[u],i,1)};I=function(g,i,n){if(g===i)return n;for(g=g.nextSibling;g;){if(g===i)return-1;g=g.nextSibling}return 1}}k.getText=function(g){for(var i="",n,m=0;g[m];m++){n=g[m];if(n.nodeType===3||n.nodeType===4)i+=n.nodeValue;else if(n.nodeType!==8)i+=k.getText(n.childNodes)}return i};(function(){var g=t.createElement("div"),
i="script"+(new Date).getTime(),n=t.documentElement;g.innerHTML="<a name='"+i+"'/>";n.insertBefore(g,n.firstChild);if(t.getElementById(i)){o.find.ID=function(m,p,q){if(typeof p.getElementById!=="undefined"&&!q)return(p=p.getElementById(m[1]))?p.id===m[1]||typeof p.getAttributeNode!=="undefined"&&p.getAttributeNode("id").nodeValue===m[1]?[p]:B:[]};o.filter.ID=function(m,p){var q=typeof m.getAttributeNode!=="undefined"&&m.getAttributeNode("id");return m.nodeType===1&&q&&q.nodeValue===p}}n.removeChild(g);
n=g=null})();(function(){var g=t.createElement("div");g.appendChild(t.createComment(""));if(g.getElementsByTagName("*").length>0)o.find.TAG=function(i,n){var m=n.getElementsByTagName(i[1]);if(i[1]==="*"){for(var p=[],q=0;m[q];q++)m[q].nodeType===1&&p.push(m[q]);m=p}return m};g.innerHTML="<a href='#'></a>";if(g.firstChild&&typeof g.firstChild.getAttribute!=="undefined"&&g.firstChild.getAttribute("href")!=="#")o.attrHandle.href=function(i){return i.getAttribute("href",2)};g=null})();t.querySelectorAll&&
function(){var g=k,i=t.createElement("div");i.innerHTML="<p class='TEST'></p>";if(!(i.querySelectorAll&&i.querySelectorAll(".TEST").length===0)){k=function(m,p,q,u){p=p||t;m=m.replace(/\=\s*([^'"\]]*)\s*\]/g,"='$1']");if(!u&&!k.isXML(p))if(p.nodeType===9)try{return C(p.querySelectorAll(m),q)}catch(y){}else if(p.nodeType===1&&p.nodeName.toLowerCase()!=="object"){var F=p.getAttribute("id"),M=F||"__sizzle__";F||p.setAttribute("id",M);try{return C(p.querySelectorAll("#"+M+" "+m),q)}catch(N){}finally{F||
p.removeAttribute("id")}}return g(m,p,q,u)};for(var n in g)k[n]=g[n];i=null}}();(function(){var g=t.documentElement,i=g.matchesSelector||g.mozMatchesSelector||g.webkitMatchesSelector||g.msMatchesSelector,n=false;try{i.call(t.documentElement,"[test!='']:sizzle")}catch(m){n=true}if(i)k.matchesSelector=function(p,q){q=q.replace(/\=\s*([^'"\]]*)\s*\]/g,"='$1']");if(!k.isXML(p))try{if(n||!o.match.PSEUDO.test(q)&&!/!=/.test(q))return i.call(p,q)}catch(u){}return k(q,null,null,[p]).length>0}})();(function(){var g=
t.createElement("div");g.innerHTML="<div class='test e'></div><div class='test'></div>";if(!(!g.getElementsByClassName||g.getElementsByClassName("e").length===0)){g.lastChild.className="e";if(g.getElementsByClassName("e").length!==1){o.order.splice(1,0,"CLASS");o.find.CLASS=function(i,n,m){if(typeof n.getElementsByClassName!=="undefined"&&!m)return n.getElementsByClassName(i[1])};g=null}}})();k.contains=t.documentElement.contains?function(g,i){return g!==i&&(g.contains?g.contains(i):true)}:t.documentElement.compareDocumentPosition?
function(g,i){return!!(g.compareDocumentPosition(i)&16)}:function(){return false};k.isXML=function(g){return(g=(g?g.ownerDocument||g:0).documentElement)?g.nodeName!=="HTML":false};var L=function(g,i){for(var n,m=[],p="",q=i.nodeType?[i]:i;n=o.match.PSEUDO.exec(g);){p+=n[0];g=g.replace(o.match.PSEUDO,"")}g=o.relative[g]?g+"*":g;n=0;for(var u=q.length;n<u;n++)k(g,q[n],m);return k.filter(p,m)};c.find=k;c.expr=k.selectors;c.expr[":"]=c.expr.filters;c.unique=k.uniqueSort;c.text=k.getText;c.isXMLDoc=k.isXML;
c.contains=k.contains})();var Za=/Until$/,$a=/^(?:parents|prevUntil|prevAll)/,ab=/,/,Na=/^.[^:#\[\.,]*$/,bb=Array.prototype.slice,cb=c.expr.match.POS;c.fn.extend({find:function(a){for(var b=this.pushStack("","find",a),d=0,e=0,f=this.length;e<f;e++){d=b.length;c.find(a,this[e],b);if(e>0)for(var h=d;h<b.length;h++)for(var l=0;l<d;l++)if(b[l]===b[h]){b.splice(h--,1);break}}return b},has:function(a){var b=c(a);return this.filter(function(){for(var d=0,e=b.length;d<e;d++)if(c.contains(this,b[d]))return true})},
not:function(a){return this.pushStack(ma(this,a,false),"not",a)},filter:function(a){return this.pushStack(ma(this,a,true),"filter",a)},is:function(a){return!!a&&c.filter(a,this).length>0},closest:function(a,b){var d=[],e,f,h=this[0];if(c.isArray(a)){var l,k={},o=1;if(h&&a.length){e=0;for(f=a.length;e<f;e++){l=a[e];k[l]||(k[l]=c.expr.match.POS.test(l)?c(l,b||this.context):l)}for(;h&&h.ownerDocument&&h!==b;){for(l in k){e=k[l];if(e.jquery?e.index(h)>-1:c(h).is(e))d.push({selector:l,elem:h,level:o})}h=
h.parentNode;o++}}return d}l=cb.test(a)?c(a,b||this.context):null;e=0;for(f=this.length;e<f;e++)for(h=this[e];h;)if(l?l.index(h)>-1:c.find.matchesSelector(h,a)){d.push(h);break}else{h=h.parentNode;if(!h||!h.ownerDocument||h===b)break}d=d.length>1?c.unique(d):d;return this.pushStack(d,"closest",a)},index:function(a){if(!a||typeof a==="string")return c.inArray(this[0],a?c(a):this.parent().children());return c.inArray(a.jquery?a[0]:a,this)},add:function(a,b){var d=typeof a==="string"?c(a,b||this.context):
c.makeArray(a),e=c.merge(this.get(),d);return this.pushStack(!d[0]||!d[0].parentNode||d[0].parentNode.nodeType===11||!e[0]||!e[0].parentNode||e[0].parentNode.nodeType===11?e:c.unique(e))},andSelf:function(){return this.add(this.prevObject)}});c.each({parent:function(a){return(a=a.parentNode)&&a.nodeType!==11?a:null},parents:function(a){return c.dir(a,"parentNode")},parentsUntil:function(a,b,d){return c.dir(a,"parentNode",d)},next:function(a){return c.nth(a,2,"nextSibling")},prev:function(a){return c.nth(a,
2,"previousSibling")},nextAll:function(a){return c.dir(a,"nextSibling")},prevAll:function(a){return c.dir(a,"previousSibling")},nextUntil:function(a,b,d){return c.dir(a,"nextSibling",d)},prevUntil:function(a,b,d){return c.dir(a,"previousSibling",d)},siblings:function(a){return c.sibling(a.parentNode.firstChild,a)},children:function(a){return c.sibling(a.firstChild)},contents:function(a){return c.nodeName(a,"iframe")?a.contentDocument||a.contentWindow.document:c.makeArray(a.childNodes)}},function(a,
b){c.fn[a]=function(d,e){var f=c.map(this,b,d);Za.test(a)||(e=d);if(e&&typeof e==="string")f=c.filter(e,f);f=this.length>1?c.unique(f):f;if((this.length>1||ab.test(e))&&$a.test(a))f=f.reverse();return this.pushStack(f,a,bb.call(arguments).join(","))}});c.extend({filter:function(a,b,d){if(d)a=":not("+a+")";return b.length===1?c.find.matchesSelector(b[0],a)?[b[0]]:[]:c.find.matches(a,b)},dir:function(a,b,d){var e=[];for(a=a[b];a&&a.nodeType!==9&&(d===B||a.nodeType!==1||!c(a).is(d));){a.nodeType===1&&
e.push(a);a=a[b]}return e},nth:function(a,b,d){b=b||1;for(var e=0;a;a=a[d])if(a.nodeType===1&&++e===b)break;return a},sibling:function(a,b){for(var d=[];a;a=a.nextSibling)a.nodeType===1&&a!==b&&d.push(a);return d}});var za=/ jQuery\d+="(?:\d+|null)"/g,$=/^\s+/,Aa=/<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:]+)[^>]*)\/>/ig,Ba=/<([\w:]+)/,db=/<tbody/i,eb=/<|&#?\w+;/,Ca=/<(?:script|object|embed|option|style)/i,Da=/checked\s*(?:[^=]|=\s*.checked.)/i,fb=/\=([^="'>\s]+\/)>/g,P={option:[1,
"<select multiple='multiple'>","</select>"],legend:[1,"<fieldset>","</fieldset>"],thead:[1,"<table>","</table>"],tr:[2,"<table><tbody>","</tbody></table>"],td:[3,"<table><tbody><tr>","</tr></tbody></table>"],col:[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"],area:[1,"<map>","</map>"],_default:[0,"",""]};P.optgroup=P.option;P.tbody=P.tfoot=P.colgroup=P.caption=P.thead;P.th=P.td;if(!c.support.htmlSerialize)P._default=[1,"div<div>","</div>"];c.fn.extend({text:function(a){if(c.isFunction(a))return this.each(function(b){var d=
c(this);d.text(a.call(this,b,d.text()))});if(typeof a!=="object"&&a!==B)return this.empty().append((this[0]&&this[0].ownerDocument||t).createTextNode(a));return c.text(this)},wrapAll:function(a){if(c.isFunction(a))return this.each(function(d){c(this).wrapAll(a.call(this,d))});if(this[0]){var b=c(a,this[0].ownerDocument).eq(0).clone(true);this[0].parentNode&&b.insertBefore(this[0]);b.map(function(){for(var d=this;d.firstChild&&d.firstChild.nodeType===1;)d=d.firstChild;return d}).append(this)}return this},
wrapInner:function(a){if(c.isFunction(a))return this.each(function(b){c(this).wrapInner(a.call(this,b))});return this.each(function(){var b=c(this),d=b.contents();d.length?d.wrapAll(a):b.append(a)})},wrap:function(a){return this.each(function(){c(this).wrapAll(a)})},unwrap:function(){return this.parent().each(function(){c.nodeName(this,"body")||c(this).replaceWith(this.childNodes)}).end()},append:function(){return this.domManip(arguments,true,function(a){this.nodeType===1&&this.appendChild(a)})},
prepend:function(){return this.domManip(arguments,true,function(a){this.nodeType===1&&this.insertBefore(a,this.firstChild)})},before:function(){if(this[0]&&this[0].parentNode)return this.domManip(arguments,false,function(b){this.parentNode.insertBefore(b,this)});else if(arguments.length){var a=c(arguments[0]);a.push.apply(a,this.toArray());return this.pushStack(a,"before",arguments)}},after:function(){if(this[0]&&this[0].parentNode)return this.domManip(arguments,false,function(b){this.parentNode.insertBefore(b,
this.nextSibling)});else if(arguments.length){var a=this.pushStack(this,"after",arguments);a.push.apply(a,c(arguments[0]).toArray());return a}},remove:function(a,b){for(var d=0,e;(e=this[d])!=null;d++)if(!a||c.filter(a,[e]).length){if(!b&&e.nodeType===1){c.cleanData(e.getElementsByTagName("*"));c.cleanData([e])}e.parentNode&&e.parentNode.removeChild(e)}return this},empty:function(){for(var a=0,b;(b=this[a])!=null;a++)for(b.nodeType===1&&c.cleanData(b.getElementsByTagName("*"));b.firstChild;)b.removeChild(b.firstChild);
return this},clone:function(a){var b=this.map(function(){if(!c.support.noCloneEvent&&!c.isXMLDoc(this)){var d=this.outerHTML,e=this.ownerDocument;if(!d){d=e.createElement("div");d.appendChild(this.cloneNode(true));d=d.innerHTML}return c.clean([d.replace(za,"").replace(fb,'="$1">').replace($,"")],e)[0]}else return this.cloneNode(true)});if(a===true){na(this,b);na(this.find("*"),b.find("*"))}return b},html:function(a){if(a===B)return this[0]&&this[0].nodeType===1?this[0].innerHTML.replace(za,""):null;
else if(typeof a==="string"&&!Ca.test(a)&&(c.support.leadingWhitespace||!$.test(a))&&!P[(Ba.exec(a)||["",""])[1].toLowerCase()]){a=a.replace(Aa,"<$1></$2>");try{for(var b=0,d=this.length;b<d;b++)if(this[b].nodeType===1){c.cleanData(this[b].getElementsByTagName("*"));this[b].innerHTML=a}}catch(e){this.empty().append(a)}}else c.isFunction(a)?this.each(function(f){var h=c(this);h.html(a.call(this,f,h.html()))}):this.empty().append(a);return this},replaceWith:function(a){if(this[0]&&this[0].parentNode){if(c.isFunction(a))return this.each(function(b){var d=
c(this),e=d.html();d.replaceWith(a.call(this,b,e))});if(typeof a!=="string")a=c(a).detach();return this.each(function(){var b=this.nextSibling,d=this.parentNode;c(this).remove();b?c(b).before(a):c(d).append(a)})}else return this.pushStack(c(c.isFunction(a)?a():a),"replaceWith",a)},detach:function(a){return this.remove(a,true)},domManip:function(a,b,d){var e,f,h,l=a[0],k=[];if(!c.support.checkClone&&arguments.length===3&&typeof l==="string"&&Da.test(l))return this.each(function(){c(this).domManip(a,
b,d,true)});if(c.isFunction(l))return this.each(function(x){var r=c(this);a[0]=l.call(this,x,b?r.html():B);r.domManip(a,b,d)});if(this[0]){e=l&&l.parentNode;e=c.support.parentNode&&e&&e.nodeType===11&&e.childNodes.length===this.length?{fragment:e}:c.buildFragment(a,this,k);h=e.fragment;if(f=h.childNodes.length===1?h=h.firstChild:h.firstChild){b=b&&c.nodeName(f,"tr");f=0;for(var o=this.length;f<o;f++)d.call(b?c.nodeName(this[f],"table")?this[f].getElementsByTagName("tbody")[0]||this[f].appendChild(this[f].ownerDocument.createElement("tbody")):
this[f]:this[f],f>0||e.cacheable||this.length>1?h.cloneNode(true):h)}k.length&&c.each(k,Oa)}return this}});c.buildFragment=function(a,b,d){var e,f,h;b=b&&b[0]?b[0].ownerDocument||b[0]:t;if(a.length===1&&typeof a[0]==="string"&&a[0].length<512&&b===t&&!Ca.test(a[0])&&(c.support.checkClone||!Da.test(a[0]))){f=true;if(h=c.fragments[a[0]])if(h!==1)e=h}if(!e){e=b.createDocumentFragment();c.clean(a,b,e,d)}if(f)c.fragments[a[0]]=h?e:1;return{fragment:e,cacheable:f}};c.fragments={};c.each({appendTo:"append",
prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(a,b){c.fn[a]=function(d){var e=[];d=c(d);var f=this.length===1&&this[0].parentNode;if(f&&f.nodeType===11&&f.childNodes.length===1&&d.length===1){d[b](this[0]);return this}else{f=0;for(var h=d.length;f<h;f++){var l=(f>0?this.clone(true):this).get();c(d[f])[b](l);e=e.concat(l)}return this.pushStack(e,a,d.selector)}}});c.extend({clean:function(a,b,d,e){b=b||t;if(typeof b.createElement==="undefined")b=b.ownerDocument||
b[0]&&b[0].ownerDocument||t;for(var f=[],h=0,l;(l=a[h])!=null;h++){if(typeof l==="number")l+="";if(l){if(typeof l==="string"&&!eb.test(l))l=b.createTextNode(l);else if(typeof l==="string"){l=l.replace(Aa,"<$1></$2>");var k=(Ba.exec(l)||["",""])[1].toLowerCase(),o=P[k]||P._default,x=o[0],r=b.createElement("div");for(r.innerHTML=o[1]+l+o[2];x--;)r=r.lastChild;if(!c.support.tbody){x=db.test(l);k=k==="table"&&!x?r.firstChild&&r.firstChild.childNodes:o[1]==="<table>"&&!x?r.childNodes:[];for(o=k.length-
1;o>=0;--o)c.nodeName(k[o],"tbody")&&!k[o].childNodes.length&&k[o].parentNode.removeChild(k[o])}!c.support.leadingWhitespace&&$.test(l)&&r.insertBefore(b.createTextNode($.exec(l)[0]),r.firstChild);l=r.childNodes}if(l.nodeType)f.push(l);else f=c.merge(f,l)}}if(d)for(h=0;f[h];h++)if(e&&c.nodeName(f[h],"script")&&(!f[h].type||f[h].type.toLowerCase()==="text/javascript"))e.push(f[h].parentNode?f[h].parentNode.removeChild(f[h]):f[h]);else{f[h].nodeType===1&&f.splice.apply(f,[h+1,0].concat(c.makeArray(f[h].getElementsByTagName("script"))));
d.appendChild(f[h])}return f},cleanData:function(a){for(var b,d,e=c.cache,f=c.event.special,h=c.support.deleteExpando,l=0,k;(k=a[l])!=null;l++)if(!(k.nodeName&&c.noData[k.nodeName.toLowerCase()]))if(d=k[c.expando]){if((b=e[d])&&b.events)for(var o in b.events)f[o]?c.event.remove(k,o):c.removeEvent(k,o,b.handle);if(h)delete k[c.expando];else k.removeAttribute&&k.removeAttribute(c.expando);delete e[d]}}});var Ea=/alpha\([^)]*\)/i,gb=/opacity=([^)]*)/,hb=/-([a-z])/ig,ib=/([A-Z])/g,Fa=/^-?\d+(?:px)?$/i,
jb=/^-?\d/,kb={position:"absolute",visibility:"hidden",display:"block"},Pa=["Left","Right"],Qa=["Top","Bottom"],W,Ga,aa,lb=function(a,b){return b.toUpperCase()};c.fn.css=function(a,b){if(arguments.length===2&&b===B)return this;return c.access(this,a,b,true,function(d,e,f){return f!==B?c.style(d,e,f):c.css(d,e)})};c.extend({cssHooks:{opacity:{get:function(a,b){if(b){var d=W(a,"opacity","opacity");return d===""?"1":d}else return a.style.opacity}}},cssNumber:{zIndex:true,fontWeight:true,opacity:true,
zoom:true,lineHeight:true},cssProps:{"float":c.support.cssFloat?"cssFloat":"styleFloat"},style:function(a,b,d,e){if(!(!a||a.nodeType===3||a.nodeType===8||!a.style)){var f,h=c.camelCase(b),l=a.style,k=c.cssHooks[h];b=c.cssProps[h]||h;if(d!==B){if(!(typeof d==="number"&&isNaN(d)||d==null)){if(typeof d==="number"&&!c.cssNumber[h])d+="px";if(!k||!("set"in k)||(d=k.set(a,d))!==B)try{l[b]=d}catch(o){}}}else{if(k&&"get"in k&&(f=k.get(a,false,e))!==B)return f;return l[b]}}},css:function(a,b,d){var e,f=c.camelCase(b),
h=c.cssHooks[f];b=c.cssProps[f]||f;if(h&&"get"in h&&(e=h.get(a,true,d))!==B)return e;else if(W)return W(a,b,f)},swap:function(a,b,d){var e={},f;for(f in b){e[f]=a.style[f];a.style[f]=b[f]}d.call(a);for(f in b)a.style[f]=e[f]},camelCase:function(a){return a.replace(hb,lb)}});c.curCSS=c.css;c.each(["height","width"],function(a,b){c.cssHooks[b]={get:function(d,e,f){var h;if(e){if(d.offsetWidth!==0)h=oa(d,b,f);else c.swap(d,kb,function(){h=oa(d,b,f)});if(h<=0){h=W(d,b,b);if(h==="0px"&&aa)h=aa(d,b,b);
if(h!=null)return h===""||h==="auto"?"0px":h}if(h<0||h==null){h=d.style[b];return h===""||h==="auto"?"0px":h}return typeof h==="string"?h:h+"px"}},set:function(d,e){if(Fa.test(e)){e=parseFloat(e);if(e>=0)return e+"px"}else return e}}});if(!c.support.opacity)c.cssHooks.opacity={get:function(a,b){return gb.test((b&&a.currentStyle?a.currentStyle.filter:a.style.filter)||"")?parseFloat(RegExp.$1)/100+"":b?"1":""},set:function(a,b){var d=a.style;d.zoom=1;var e=c.isNaN(b)?"":"alpha(opacity="+b*100+")",f=
d.filter||"";d.filter=Ea.test(f)?f.replace(Ea,e):d.filter+" "+e}};if(t.defaultView&&t.defaultView.getComputedStyle)Ga=function(a,b,d){var e;d=d.replace(ib,"-$1").toLowerCase();if(!(b=a.ownerDocument.defaultView))return B;if(b=b.getComputedStyle(a,null)){e=b.getPropertyValue(d);if(e===""&&!c.contains(a.ownerDocument.documentElement,a))e=c.style(a,d)}return e};if(t.documentElement.currentStyle)aa=function(a,b){var d,e,f=a.currentStyle&&a.currentStyle[b],h=a.style;if(!Fa.test(f)&&jb.test(f)){d=h.left;
e=a.runtimeStyle.left;a.runtimeStyle.left=a.currentStyle.left;h.left=b==="fontSize"?"1em":f||0;f=h.pixelLeft+"px";h.left=d;a.runtimeStyle.left=e}return f===""?"auto":f};W=Ga||aa;if(c.expr&&c.expr.filters){c.expr.filters.hidden=function(a){var b=a.offsetHeight;return a.offsetWidth===0&&b===0||!c.support.reliableHiddenOffsets&&(a.style.display||c.css(a,"display"))==="none"};c.expr.filters.visible=function(a){return!c.expr.filters.hidden(a)}}var mb=c.now(),nb=/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
ob=/^(?:select|textarea)/i,pb=/^(?:color|date|datetime|email|hidden|month|number|password|range|search|tel|text|time|url|week)$/i,qb=/^(?:GET|HEAD)$/,Ra=/\[\]$/,T=/\=\?(&|$)/,ja=/\?/,rb=/([?&])_=[^&]*/,sb=/^(\w+:)?\/\/([^\/?#]+)/,tb=/%20/g,ub=/#.*$/,Ha=c.fn.load;c.fn.extend({load:function(a,b,d){if(typeof a!=="string"&&Ha)return Ha.apply(this,arguments);else if(!this.length)return this;var e=a.indexOf(" ");if(e>=0){var f=a.slice(e,a.length);a=a.slice(0,e)}e="GET";if(b)if(c.isFunction(b)){d=b;b=null}else if(typeof b===
"object"){b=c.param(b,c.ajaxSettings.traditional);e="POST"}var h=this;c.ajax({url:a,type:e,dataType:"html",data:b,complete:function(l,k){if(k==="success"||k==="notmodified")h.html(f?c("<div>").append(l.responseText.replace(nb,"")).find(f):l.responseText);d&&h.each(d,[l.responseText,k,l])}});return this},serialize:function(){return c.param(this.serializeArray())},serializeArray:function(){return this.map(function(){return this.elements?c.makeArray(this.elements):this}).filter(function(){return this.name&&
!this.disabled&&(this.checked||ob.test(this.nodeName)||pb.test(this.type))}).map(function(a,b){var d=c(this).val();return d==null?null:c.isArray(d)?c.map(d,function(e){return{name:b.name,value:e}}):{name:b.name,value:d}}).get()}});c.each("ajaxStart ajaxStop ajaxComplete ajaxError ajaxSuccess ajaxSend".split(" "),function(a,b){c.fn[b]=function(d){return this.bind(b,d)}});c.extend({get:function(a,b,d,e){if(c.isFunction(b)){e=e||d;d=b;b=null}return c.ajax({type:"GET",url:a,data:b,success:d,dataType:e})},
getScript:function(a,b){return c.get(a,null,b,"script")},getJSON:function(a,b,d){return c.get(a,b,d,"json")},post:function(a,b,d,e){if(c.isFunction(b)){e=e||d;d=b;b={}}return c.ajax({type:"POST",url:a,data:b,success:d,dataType:e})},ajaxSetup:function(a){c.extend(c.ajaxSettings,a)},ajaxSettings:{url:location.href,global:true,type:"GET",contentType:"application/x-www-form-urlencoded",processData:true,async:true,xhr:function(){return new E.XMLHttpRequest},accepts:{xml:"application/xml, text/xml",html:"text/html",
script:"text/javascript, application/javascript",json:"application/json, text/javascript",text:"text/plain",_default:"*/*"}},ajax:function(a){var b=c.extend(true,{},c.ajaxSettings,a),d,e,f,h=b.type.toUpperCase(),l=qb.test(h);b.url=b.url.replace(ub,"");b.context=a&&a.context!=null?a.context:b;if(b.data&&b.processData&&typeof b.data!=="string")b.data=c.param(b.data,b.traditional);if(b.dataType==="jsonp"){if(h==="GET")T.test(b.url)||(b.url+=(ja.test(b.url)?"&":"?")+(b.jsonp||"callback")+"=?");else if(!b.data||
!T.test(b.data))b.data=(b.data?b.data+"&":"")+(b.jsonp||"callback")+"=?";b.dataType="json"}if(b.dataType==="json"&&(b.data&&T.test(b.data)||T.test(b.url))){d=b.jsonpCallback||"jsonp"+mb++;if(b.data)b.data=(b.data+"").replace(T,"="+d+"$1");b.url=b.url.replace(T,"="+d+"$1");b.dataType="script";var k=E[d];E[d]=function(m){if(c.isFunction(k))k(m);else{E[d]=B;try{delete E[d]}catch(p){}}f=m;c.handleSuccess(b,w,e,f);c.handleComplete(b,w,e,f);r&&r.removeChild(A)}}if(b.dataType==="script"&&b.cache===null)b.cache=
false;if(b.cache===false&&l){var o=c.now(),x=b.url.replace(rb,"$1_="+o);b.url=x+(x===b.url?(ja.test(b.url)?"&":"?")+"_="+o:"")}if(b.data&&l)b.url+=(ja.test(b.url)?"&":"?")+b.data;b.global&&c.active++===0&&c.event.trigger("ajaxStart");o=(o=sb.exec(b.url))&&(o[1]&&o[1].toLowerCase()!==location.protocol||o[2].toLowerCase()!==location.host);if(b.dataType==="script"&&h==="GET"&&o){var r=t.getElementsByTagName("head")[0]||t.documentElement,A=t.createElement("script");if(b.scriptCharset)A.charset=b.scriptCharset;
A.src=b.url;if(!d){var C=false;A.onload=A.onreadystatechange=function(){if(!C&&(!this.readyState||this.readyState==="loaded"||this.readyState==="complete")){C=true;c.handleSuccess(b,w,e,f);c.handleComplete(b,w,e,f);A.onload=A.onreadystatechange=null;r&&A.parentNode&&r.removeChild(A)}}}r.insertBefore(A,r.firstChild);return B}var J=false,w=b.xhr();if(w){b.username?w.open(h,b.url,b.async,b.username,b.password):w.open(h,b.url,b.async);try{if(b.data!=null&&!l||a&&a.contentType)w.setRequestHeader("Content-Type",
b.contentType);if(b.ifModified){c.lastModified[b.url]&&w.setRequestHeader("If-Modified-Since",c.lastModified[b.url]);c.etag[b.url]&&w.setRequestHeader("If-None-Match",c.etag[b.url])}o||w.setRequestHeader("X-Requested-With","XMLHttpRequest");w.setRequestHeader("Accept",b.dataType&&b.accepts[b.dataType]?b.accepts[b.dataType]+", */*; q=0.01":b.accepts._default)}catch(I){}if(b.beforeSend&&b.beforeSend.call(b.context,w,b)===false){b.global&&c.active--===1&&c.event.trigger("ajaxStop");w.abort();return false}b.global&&
c.triggerGlobal(b,"ajaxSend",[w,b]);var L=w.onreadystatechange=function(m){if(!w||w.readyState===0||m==="abort"){J||c.handleComplete(b,w,e,f);J=true;if(w)w.onreadystatechange=c.noop}else if(!J&&w&&(w.readyState===4||m==="timeout")){J=true;w.onreadystatechange=c.noop;e=m==="timeout"?"timeout":!c.httpSuccess(w)?"error":b.ifModified&&c.httpNotModified(w,b.url)?"notmodified":"success";var p;if(e==="success")try{f=c.httpData(w,b.dataType,b)}catch(q){e="parsererror";p=q}if(e==="success"||e==="notmodified")d||
c.handleSuccess(b,w,e,f);else c.handleError(b,w,e,p);d||c.handleComplete(b,w,e,f);m==="timeout"&&w.abort();if(b.async)w=null}};try{var g=w.abort;w.abort=function(){w&&Function.prototype.call.call(g,w);L("abort")}}catch(i){}b.async&&b.timeout>0&&setTimeout(function(){w&&!J&&L("timeout")},b.timeout);try{w.send(l||b.data==null?null:b.data)}catch(n){c.handleError(b,w,null,n);c.handleComplete(b,w,e,f)}b.async||L();return w}},param:function(a,b){var d=[],e=function(h,l){l=c.isFunction(l)?l():l;d[d.length]=
encodeURIComponent(h)+"="+encodeURIComponent(l)};if(b===B)b=c.ajaxSettings.traditional;if(c.isArray(a)||a.jquery)c.each(a,function(){e(this.name,this.value)});else for(var f in a)da(f,a[f],b,e);return d.join("&").replace(tb,"+")}});c.extend({active:0,lastModified:{},etag:{},handleError:function(a,b,d,e){a.error&&a.error.call(a.context,b,d,e);a.global&&c.triggerGlobal(a,"ajaxError",[b,a,e])},handleSuccess:function(a,b,d,e){a.success&&a.success.call(a.context,e,d,b);a.global&&c.triggerGlobal(a,"ajaxSuccess",
[b,a])},handleComplete:function(a,b,d){a.complete&&a.complete.call(a.context,b,d);a.global&&c.triggerGlobal(a,"ajaxComplete",[b,a]);a.global&&c.active--===1&&c.event.trigger("ajaxStop")},triggerGlobal:function(a,b,d){(a.context&&a.context.url==null?c(a.context):c.event).trigger(b,d)},httpSuccess:function(a){try{return!a.status&&location.protocol==="file:"||a.status>=200&&a.status<300||a.status===304||a.status===1223}catch(b){}return false},httpNotModified:function(a,b){var d=a.getResponseHeader("Last-Modified"),
e=a.getResponseHeader("Etag");if(d)c.lastModified[b]=d;if(e)c.etag[b]=e;return a.status===304},httpData:function(a,b,d){var e=a.getResponseHeader("content-type")||"",f=b==="xml"||!b&&e.indexOf("xml")>=0;a=f?a.responseXML:a.responseText;f&&a.documentElement.nodeName==="parsererror"&&c.error("parsererror");if(d&&d.dataFilter)a=d.dataFilter(a,b);if(typeof a==="string")if(b==="json"||!b&&e.indexOf("json")>=0)a=c.parseJSON(a);else if(b==="script"||!b&&e.indexOf("javascript")>=0)c.globalEval(a);return a}});
if(E.ActiveXObject)c.ajaxSettings.xhr=function(){if(E.location.protocol!=="file:")try{return new E.XMLHttpRequest}catch(a){}try{return new E.ActiveXObject("Microsoft.XMLHTTP")}catch(b){}};c.support.ajax=!!c.ajaxSettings.xhr();var ea={},vb=/^(?:toggle|show|hide)$/,wb=/^([+\-]=)?([\d+.\-]+)(.*)$/,ba,pa=[["height","marginTop","marginBottom","paddingTop","paddingBottom"],["width","marginLeft","marginRight","paddingLeft","paddingRight"],["opacity"]];c.fn.extend({show:function(a,b,d){if(a||a===0)return this.animate(S("show",
3),a,b,d);else{d=0;for(var e=this.length;d<e;d++){a=this[d];b=a.style.display;if(!c.data(a,"olddisplay")&&b==="none")b=a.style.display="";b===""&&c.css(a,"display")==="none"&&c.data(a,"olddisplay",qa(a.nodeName))}for(d=0;d<e;d++){a=this[d];b=a.style.display;if(b===""||b==="none")a.style.display=c.data(a,"olddisplay")||""}return this}},hide:function(a,b,d){if(a||a===0)return this.animate(S("hide",3),a,b,d);else{a=0;for(b=this.length;a<b;a++){d=c.css(this[a],"display");d!=="none"&&c.data(this[a],"olddisplay",
d)}for(a=0;a<b;a++)this[a].style.display="none";return this}},_toggle:c.fn.toggle,toggle:function(a,b,d){var e=typeof a==="boolean";if(c.isFunction(a)&&c.isFunction(b))this._toggle.apply(this,arguments);else a==null||e?this.each(function(){var f=e?a:c(this).is(":hidden");c(this)[f?"show":"hide"]()}):this.animate(S("toggle",3),a,b,d);return this},fadeTo:function(a,b,d,e){return this.filter(":hidden").css("opacity",0).show().end().animate({opacity:b},a,d,e)},animate:function(a,b,d,e){var f=c.speed(b,
d,e);if(c.isEmptyObject(a))return this.each(f.complete);return this[f.queue===false?"each":"queue"](function(){var h=c.extend({},f),l,k=this.nodeType===1,o=k&&c(this).is(":hidden"),x=this;for(l in a){var r=c.camelCase(l);if(l!==r){a[r]=a[l];delete a[l];l=r}if(a[l]==="hide"&&o||a[l]==="show"&&!o)return h.complete.call(this);if(k&&(l==="height"||l==="width")){h.overflow=[this.style.overflow,this.style.overflowX,this.style.overflowY];if(c.css(this,"display")==="inline"&&c.css(this,"float")==="none")if(c.support.inlineBlockNeedsLayout)if(qa(this.nodeName)===
"inline")this.style.display="inline-block";else{this.style.display="inline";this.style.zoom=1}else this.style.display="inline-block"}if(c.isArray(a[l])){(h.specialEasing=h.specialEasing||{})[l]=a[l][1];a[l]=a[l][0]}}if(h.overflow!=null)this.style.overflow="hidden";h.curAnim=c.extend({},a);c.each(a,function(A,C){var J=new c.fx(x,h,A);if(vb.test(C))J[C==="toggle"?o?"show":"hide":C](a);else{var w=wb.exec(C),I=J.cur()||0;if(w){var L=parseFloat(w[2]),g=w[3]||"px";if(g!=="px"){c.style(x,A,(L||1)+g);I=(L||
1)/J.cur()*I;c.style(x,A,I+g)}if(w[1])L=(w[1]==="-="?-1:1)*L+I;J.custom(I,L,g)}else J.custom(I,C,"")}});return true})},stop:function(a,b){var d=c.timers;a&&this.queue([]);this.each(function(){for(var e=d.length-1;e>=0;e--)if(d[e].elem===this){b&&d[e](true);d.splice(e,1)}});b||this.dequeue();return this}});c.each({slideDown:S("show",1),slideUp:S("hide",1),slideToggle:S("toggle",1),fadeIn:{opacity:"show"},fadeOut:{opacity:"hide"},fadeToggle:{opacity:"toggle"}},function(a,b){c.fn[a]=function(d,e,f){return this.animate(b,
d,e,f)}});c.extend({speed:function(a,b,d){var e=a&&typeof a==="object"?c.extend({},a):{complete:d||!d&&b||c.isFunction(a)&&a,duration:a,easing:d&&b||b&&!c.isFunction(b)&&b};e.duration=c.fx.off?0:typeof e.duration==="number"?e.duration:e.duration in c.fx.speeds?c.fx.speeds[e.duration]:c.fx.speeds._default;e.old=e.complete;e.complete=function(){e.queue!==false&&c(this).dequeue();c.isFunction(e.old)&&e.old.call(this)};return e},easing:{linear:function(a,b,d,e){return d+e*a},swing:function(a,b,d,e){return(-Math.cos(a*
Math.PI)/2+0.5)*e+d}},timers:[],fx:function(a,b,d){this.options=b;this.elem=a;this.prop=d;if(!b.orig)b.orig={}}});c.fx.prototype={update:function(){this.options.step&&this.options.step.call(this.elem,this.now,this);(c.fx.step[this.prop]||c.fx.step._default)(this)},cur:function(){if(this.elem[this.prop]!=null&&(!this.elem.style||this.elem.style[this.prop]==null))return this.elem[this.prop];var a=parseFloat(c.css(this.elem,this.prop));return a&&a>-1E4?a:0},custom:function(a,b,d){function e(l){return f.step(l)}
var f=this,h=c.fx;this.startTime=c.now();this.start=a;this.end=b;this.unit=d||this.unit||"px";this.now=this.start;this.pos=this.state=0;e.elem=this.elem;if(e()&&c.timers.push(e)&&!ba)ba=setInterval(h.tick,h.interval)},show:function(){this.options.orig[this.prop]=c.style(this.elem,this.prop);this.options.show=true;this.custom(this.prop==="width"||this.prop==="height"?1:0,this.cur());c(this.elem).show()},hide:function(){this.options.orig[this.prop]=c.style(this.elem,this.prop);this.options.hide=true;
this.custom(this.cur(),0)},step:function(a){var b=c.now(),d=true;if(a||b>=this.options.duration+this.startTime){this.now=this.end;this.pos=this.state=1;this.update();this.options.curAnim[this.prop]=true;for(var e in this.options.curAnim)if(this.options.curAnim[e]!==true)d=false;if(d){if(this.options.overflow!=null&&!c.support.shrinkWrapBlocks){var f=this.elem,h=this.options;c.each(["","X","Y"],function(k,o){f.style["overflow"+o]=h.overflow[k]})}this.options.hide&&c(this.elem).hide();if(this.options.hide||
this.options.show)for(var l in this.options.curAnim)c.style(this.elem,l,this.options.orig[l]);this.options.complete.call(this.elem)}return false}else{a=b-this.startTime;this.state=a/this.options.duration;b=this.options.easing||(c.easing.swing?"swing":"linear");this.pos=c.easing[this.options.specialEasing&&this.options.specialEasing[this.prop]||b](this.state,a,0,1,this.options.duration);this.now=this.start+(this.end-this.start)*this.pos;this.update()}return true}};c.extend(c.fx,{tick:function(){for(var a=
c.timers,b=0;b<a.length;b++)a[b]()||a.splice(b--,1);a.length||c.fx.stop()},interval:13,stop:function(){clearInterval(ba);ba=null},speeds:{slow:600,fast:200,_default:400},step:{opacity:function(a){c.style(a.elem,"opacity",a.now)},_default:function(a){if(a.elem.style&&a.elem.style[a.prop]!=null)a.elem.style[a.prop]=(a.prop==="width"||a.prop==="height"?Math.max(0,a.now):a.now)+a.unit;else a.elem[a.prop]=a.now}}});if(c.expr&&c.expr.filters)c.expr.filters.animated=function(a){return c.grep(c.timers,function(b){return a===
b.elem}).length};var xb=/^t(?:able|d|h)$/i,Ia=/^(?:body|html)$/i;c.fn.offset="getBoundingClientRect"in t.documentElement?function(a){var b=this[0],d;if(a)return this.each(function(l){c.offset.setOffset(this,a,l)});if(!b||!b.ownerDocument)return null;if(b===b.ownerDocument.body)return c.offset.bodyOffset(b);try{d=b.getBoundingClientRect()}catch(e){}var f=b.ownerDocument,h=f.documentElement;if(!d||!c.contains(h,b))return d||{top:0,left:0};b=f.body;f=fa(f);return{top:d.top+(f.pageYOffset||c.support.boxModel&&
h.scrollTop||b.scrollTop)-(h.clientTop||b.clientTop||0),left:d.left+(f.pageXOffset||c.support.boxModel&&h.scrollLeft||b.scrollLeft)-(h.clientLeft||b.clientLeft||0)}}:function(a){var b=this[0];if(a)return this.each(function(x){c.offset.setOffset(this,a,x)});if(!b||!b.ownerDocument)return null;if(b===b.ownerDocument.body)return c.offset.bodyOffset(b);c.offset.initialize();var d,e=b.offsetParent,f=b.ownerDocument,h=f.documentElement,l=f.body;d=(f=f.defaultView)?f.getComputedStyle(b,null):b.currentStyle;
for(var k=b.offsetTop,o=b.offsetLeft;(b=b.parentNode)&&b!==l&&b!==h;){if(c.offset.supportsFixedPosition&&d.position==="fixed")break;d=f?f.getComputedStyle(b,null):b.currentStyle;k-=b.scrollTop;o-=b.scrollLeft;if(b===e){k+=b.offsetTop;o+=b.offsetLeft;if(c.offset.doesNotAddBorder&&!(c.offset.doesAddBorderForTableAndCells&&xb.test(b.nodeName))){k+=parseFloat(d.borderTopWidth)||0;o+=parseFloat(d.borderLeftWidth)||0}e=b.offsetParent}if(c.offset.subtractsBorderForOverflowNotVisible&&d.overflow!=="visible"){k+=
parseFloat(d.borderTopWidth)||0;o+=parseFloat(d.borderLeftWidth)||0}d=d}if(d.position==="relative"||d.position==="static"){k+=l.offsetTop;o+=l.offsetLeft}if(c.offset.supportsFixedPosition&&d.position==="fixed"){k+=Math.max(h.scrollTop,l.scrollTop);o+=Math.max(h.scrollLeft,l.scrollLeft)}return{top:k,left:o}};c.offset={initialize:function(){var a=t.body,b=t.createElement("div"),d,e,f,h=parseFloat(c.css(a,"marginTop"))||0;c.extend(b.style,{position:"absolute",top:0,left:0,margin:0,border:0,width:"1px",
height:"1px",visibility:"hidden"});b.innerHTML="<div style='position:absolute;top:0;left:0;margin:0;border:5px solid #000;padding:0;width:1px;height:1px;'><div></div></div><table style='position:absolute;top:0;left:0;margin:0;border:5px solid #000;padding:0;width:1px;height:1px;' cellpadding='0' cellspacing='0'><tr><td></td></tr></table>";a.insertBefore(b,a.firstChild);d=b.firstChild;e=d.firstChild;f=d.nextSibling.firstChild.firstChild;this.doesNotAddBorder=e.offsetTop!==5;this.doesAddBorderForTableAndCells=
f.offsetTop===5;e.style.position="fixed";e.style.top="20px";this.supportsFixedPosition=e.offsetTop===20||e.offsetTop===15;e.style.position=e.style.top="";d.style.overflow="hidden";d.style.position="relative";this.subtractsBorderForOverflowNotVisible=e.offsetTop===-5;this.doesNotIncludeMarginInBodyOffset=a.offsetTop!==h;a.removeChild(b);c.offset.initialize=c.noop},bodyOffset:function(a){var b=a.offsetTop,d=a.offsetLeft;c.offset.initialize();if(c.offset.doesNotIncludeMarginInBodyOffset){b+=parseFloat(c.css(a,
"marginTop"))||0;d+=parseFloat(c.css(a,"marginLeft"))||0}return{top:b,left:d}},setOffset:function(a,b,d){var e=c.css(a,"position");if(e==="static")a.style.position="relative";var f=c(a),h=f.offset(),l=c.css(a,"top"),k=c.css(a,"left"),o=e==="absolute"&&c.inArray("auto",[l,k])>-1;e={};var x={};if(o)x=f.position();l=o?x.top:parseInt(l,10)||0;k=o?x.left:parseInt(k,10)||0;if(c.isFunction(b))b=b.call(a,d,h);if(b.top!=null)e.top=b.top-h.top+l;if(b.left!=null)e.left=b.left-h.left+k;"using"in b?b.using.call(a,
e):f.css(e)}};c.fn.extend({position:function(){if(!this[0])return null;var a=this[0],b=this.offsetParent(),d=this.offset(),e=Ia.test(b[0].nodeName)?{top:0,left:0}:b.offset();d.top-=parseFloat(c.css(a,"marginTop"))||0;d.left-=parseFloat(c.css(a,"marginLeft"))||0;e.top+=parseFloat(c.css(b[0],"borderTopWidth"))||0;e.left+=parseFloat(c.css(b[0],"borderLeftWidth"))||0;return{top:d.top-e.top,left:d.left-e.left}},offsetParent:function(){return this.map(function(){for(var a=this.offsetParent||t.body;a&&!Ia.test(a.nodeName)&&
c.css(a,"position")==="static";)a=a.offsetParent;return a})}});c.each(["Left","Top"],function(a,b){var d="scroll"+b;c.fn[d]=function(e){var f=this[0],h;if(!f)return null;if(e!==B)return this.each(function(){if(h=fa(this))h.scrollTo(!a?e:c(h).scrollLeft(),a?e:c(h).scrollTop());else this[d]=e});else return(h=fa(f))?"pageXOffset"in h?h[a?"pageYOffset":"pageXOffset"]:c.support.boxModel&&h.document.documentElement[d]||h.document.body[d]:f[d]}});c.each(["Height","Width"],function(a,b){var d=b.toLowerCase();
c.fn["inner"+b]=function(){return this[0]?parseFloat(c.css(this[0],d,"padding")):null};c.fn["outer"+b]=function(e){return this[0]?parseFloat(c.css(this[0],d,e?"margin":"border")):null};c.fn[d]=function(e){var f=this[0];if(!f)return e==null?null:this;if(c.isFunction(e))return this.each(function(l){var k=c(this);k[d](e.call(this,l,k[d]()))});if(c.isWindow(f))return f.document.compatMode==="CSS1Compat"&&f.document.documentElement["client"+b]||f.document.body["client"+b];else if(f.nodeType===9)return Math.max(f.documentElement["client"+
b],f.body["scroll"+b],f.documentElement["scroll"+b],f.body["offset"+b],f.documentElement["offset"+b]);else if(e===B){f=c.css(f,d);var h=parseFloat(f);return c.isNaN(h)?f:h}else return this.css(d,typeof e==="string"?e:e+"px")}})})(window);
;
// BEGIN jquery-patch.js
(function ($) {
/* Overload jQuery's getScript to always place script tags in the head rather
 * than evaling them
 */
$.getScript = function (url, callback) {
    var head = document.getElementsByTagName("head")[0];
    var script = document.createElement("script");
    script.src = url;

    var done = false;

    // Attach handlers for all browsers
    script.onload = script.onreadystatechange = function() {
        if ( !done && (!this.readyState ||
             this.readyState == "loaded" || this.readyState == "complete") ) {
            done = true;
            if ($.isFunction(callback))
                callback();
        }
    };
    head.appendChild(script);
};

$.fn.serializeHash = function() {
    var hash = {};
    $(this).each(function() {
        $.each($(this).serializeArray(), function(i, el) {
            hash[ el.name ] = el.value
        });
    });
    return hash;
};

})(jQuery);
;
// BEGIN jquery.selectOverlap.js
(function($){
    
    function width_height (node, opts) {
        var w = $(node).width();
        var h = $(node).height();
        if (!opts.noPadding) {
            w += 2;
            h += 2;
        }
        return {width:  w, height: h};
    }

    $.fn.createSelectOverlap = function() {
        var opts = {};
        if (arguments.length) opts = arguments[0];
        if ($.browser.msie && $.browser.version < 7) {
            this.each(function(){
                var $iframe = $('iframe.iframeHack', this);
                if ($iframe.size() == 0) {
                    $iframe = $('<iframe src="/static/html/blank.html"></iframe>')
                        .addClass('iframeHack')
                        .css({
                            position: 'absolute',
                            filter: "alpha(opacity=0)",
                            top:    opts.noPadding ? 0 : -1,
                            left:   opts.noPadding ? 0 : -1,
                            zIndex: opts.zIndex || -1
                        })
                        .appendTo(this);
                }

                $(this).mouseover(function() {
                    $iframe.css(width_height(this, opts));
                });
                $iframe.css(width_height(this, opts));
            });
        }
        return this;
    };
})(jQuery);
;
// BEGIN lookahead.js
(function($){
    var SELECTED_COLOR = '#CCC';
    var BG_COLOR = '#EEE';
    var lookaheads = [];

    var hastyped = false;

    var DEFAULTS = {
        count: 10,
        filterName: 'filter',
        filterType: 'sql',
        requireMatch: false,
        params: { 
            order: 'alpha',
            count: 30, // for fetching
            minimal: 1
        }
    };

    var FILTER_TYPES = {
        plain: '$1',
        sql: '\\b$1',
        solr: '$1* OR $1'
    };

    var KEYCODES = {
        DOWN: 40,
        UP: 38,
        ENTER: 13,
        SHIFT: 16,
        ESC: 27,
        TAB: 9
    };

    Lookahead = function (input, opts) {
        if (!input) throw new Error("Missing input element");
        if (!opts.url) throw new Error("url missing");
        if (!opts.linkText) throw new Error("linkText missing");

        var targetWindow = opts.getWindow && opts.getWindow();
        if (targetWindow) {
            this.window = targetWindow;
            this.$ = targetWindow.jQuery;
        }
        else {
            this.window = window;
            this.$ = jQuery;
        }

        this._items = [];
        this.input = input;
        this.opts = $.extend(true, {}, DEFAULTS, opts); // deep extend
        var self = this;

        if (this.opts.clickCurrentButton) {
            this.opts.clickCurrentButton.unbind('click').click(function() {
                self.clickCurrent();
                return false;
            });
        }

        $(this.input)
            .attr('autocomplete', 'off')
            .unbind('keyup')
            .keyup(function(e) {
                if (e.keyCode == KEYCODES.ESC) {
                    $(input).val('').blur();
                    self.clearLookahead();
                }
                else if (e.keyCode == KEYCODES.ENTER) {
                    if (self.opts.requireMatch) {
                        if (self._items.length) {
                            self.clickCurrent();
                        }
                    }
                    else {
                        self.acceptInputValue();
                    }
                }
                else if (e.keyCode == KEYCODES.DOWN) {
                    self.selectDown();
                }
                else if (e.keyCode == KEYCODES.UP) {
                    self.selectUp();
                }
                else if (e.keyCode != KEYCODES.TAB && e.keyCode != KEYCODES.SHIFT) {
                    self.onchange();
                }
                return false;
            })
            .unbind('keydown')
            .keydown(function(e) {
                if (!self.hastyped) {
                    self.hastyped=true;
                    if (self.opts.onFirstType) {
                        self.opts.onFirstType($(self.input));
                    }
                }
                if (self.lookahead && self.lookahead.is(':visible')) {
                    if (e.keyCode == KEYCODES.TAB) {
                        // tab complete rather than select
                        self.selectDown();
                        return false;
                    }
                    else if (e.keyCode == KEYCODES.ENTER) {
                        return false;
                    }
                }
            })
            .unbind('blur')
            .blur(function(e) {
                setTimeout(function() {
                    if (self._accepting) {
                        self._accepting = false;
                        $(self.input).focus();
                    }
                    else {
                        self.clearLookahead();
                        if ($.isFunction(self.opts.onBlur)) {
                            self.opts.onBlur(action);
                        }
                    }
                }, 50);
            });

        this.allowMouseClicks();
    }

    $.fn.lookahead = function(opts) {
        this.each(function(){
            this.lookahead = new Lookahead(this, opts); 
            lookaheads.push(this.lookahead);
        });

        return this;
    };

    $.fn.abortLookahead = function() {
        this.each(function() {
            this.lookahead.abort();
        });
    }

    Lookahead.prototype = {
        'window': window,
        '$': window.$
    };

    Lookahead.prototype.allowMouseClicks = function() { 
        var self = this;

        var elements = [ this.getLookahead() ];
        if (this.opts.allowMouseClicks)
            elements.push(this.opts.allowMouseClicks);

        $.each(elements, function () {
            $(this).unbind('mousedown').mousedown(function() {
                // IE: Use _accepting to prevent onBlur
                if ($.browser.msie) self._accepting = true;
                $(self.input).focus();
                // Firefox: This works because this is called before blur
                return false;
            });
        });
    };

    Lookahead.prototype.clearLookahead = function () {
        this._cache = {};
        this._items = [];
        this.hide();
    };

    Lookahead.prototype.getLookahead = function () {
        /* Subract the offsets of all absolutely positioned parents
         * so that we can position the lookahead directly below the
         * input element. I think jQuery's offset function should do
         * this for you, but maybe they'll fix it eventually...
         */
        var left = $(this.input).offset().left;
        var top = $(this.input).offset().top + $(this.input).height() + 10;

        if (this.window !== window) {
            // XXX: container specific
            var offset = this.$('iframe[name='+window.name+']').offset();
            if (offset) {
                left += offset.left;
                top += offset.top;
            }

            // Map unload to remove the lookahead, otherwise it can hang
            // around after we move a widget
            var self = this;
            $(window).unload(function() {
                self.lookahead.remove();
            });
        }

        if (!this.lookahead) {
            this.lookahead = this.$('<div></div>')
                .hide()
                .css({
                    textAlign: 'left',
                    zIndex: 3001,
                    position: 'absolute',
                    display: 'none', // Safari needs this explicitly: {bz: 2431}
                    background: BG_COLOR,
                    border: '1px solid black',
                    padding: '0px'
                })
                .prependTo('body');

            this.$('<ul></ul>')
                .css({
                    listStyle: 'none',
                    padding: '0',
                    margin: '0'
                })
                .appendTo(this.lookahead);

        }

        this.lookahead.css({
            left: left + 'px',
            top: top + 'px'
        });

        return this.lookahead;
    };

    Lookahead.prototype.getLookaheadList = function () {
        return this.$('ul', this.getLookahead());
    };

    Lookahead.prototype.linkTitle = function (item) {
        var lt = this.opts.linkText(item);
        return typeof (lt) == 'string' ? lt : lt[0];
    };

    Lookahead.prototype.linkDesc = function (item) {
        var lt = this.opts.linkText(item);
        return typeof (lt) == 'string' ? '' : lt[2];
    };

    Lookahead.prototype.linkValue = function (item) {
        var lt = this.opts.linkText(item);
        return typeof (lt) == 'string' ? lt : lt[1];
    };

    Lookahead.prototype.filterRE = function (val) {
        var pattern = '(' + val + ')';

        if (/^\w/.test(val)) {
            pattern = "\\b" + pattern;
        }

        return new RegExp(pattern, 'ig');
    };
    
    Lookahead.prototype.filterData = function (val, data) {
        var self = this;

        var filtered = [];
        var re = this.filterRE(val);

        $.each(data, function(i, item) {
            if (filtered.length >= self.opts.count) {
                if (self.opts.showAll) {
                    filtered.push({
                        title: loc("lookahead.all-results"),
                        displayAs: val,
                        noThumbnail: true,
                        onAccept: function() {
                            self.opts.showAll(val)
                        }
                    });
                    return false; // Break out of the $.each loop
                }
                return;
            }

            var title = self.linkTitle(item);
            var desc = self.linkDesc(item) || '';

            if (title.match(re) || desc.match(re)) {
                if (self.opts.grep && !self.opts.grep(item)) return;

                /* Add <b></b> and escape < and > in original text */
                var _Mark_ = String.fromCharCode(0xFFFC);
                var _Done_ = String.fromCharCode(0xFFFD);

                filtered.push({
                    bolded_title: title.replace(re, _Mark_ + '$1' + _Done_)
                        .replace(/</g, "&lt;")
                        .replace(/>/g, "&gt;")
                        .replace(new RegExp(_Mark_, 'g'), '<b>')
                        .replace(new RegExp(_Done_, 'g'), '</b>'),
                    title: title,
                    bolded_desc: desc.replace(re, _Mark_ + '$1' + _Done_)
                        .replace(/</g, "&lt;")
                        .replace(/>/g, "&gt;")
                        .replace(new RegExp(_Mark_, 'g'), '<b>')
                        .replace(new RegExp(_Done_, 'g'), '</b>'),
                    desc: desc,
                    value: self.linkValue(item),
                    orig: item
                });
            }
        });

        return filtered;
    };

    Lookahead.prototype.displayData = function (data) {
        var self = this;
        this._items = data;
        var lookaheadList = this.getLookaheadList();
        lookaheadList.html('');

        if (data.length) {
            $.each(data, function (i) {
                var item = this || {};
                var li = self.$('<li></li>')
                    .css({
                        padding: '3px 5px',
                        height: '15px', // overridden when there are thumbnails
                        lineHeight: '15px',
                        'float': 'left',
                        'clear': 'both'
                    })
                    .appendTo(lookaheadList);
                if (self.opts.getEntryThumbnail && !item.noThumbnail) {
                    // lookaheads with thumbnails are taller
                    li.height(30);
                    if (!item.desc) li.css('line-height', '30px');

                    var src = self.opts.getEntryThumbnail(item); 
                    self.$('<img/>')
                        .css({
                            'vertical-align': 'middle',
                            'marginRight': '5px',
                            'border': '1px solid #666',
                            'cursor': 'pointer',
                            'float': 'left',
                            'width': '27px',
                            'height': '27px'
                        })
                        .click(function() {
                            self.accept(i);
                            return false;
                        })
                        .attr('src', src)
                        .appendTo(li);
                }
                self.itemNode(item, i).appendTo(li);
            });
            this.show();
        }
        else {
            lookaheadList.html('<li></li>');
            $('li', lookaheadList)
                .text(loc("error.no-match=lookahead", $(this.input).val()))
                .css({padding: '3px 5px'});
            this.show();
        }
    };

    Lookahead.prototype.itemNode = function(item, index) {
        var self = this;
        var $node = self.$('<div class="lookaheadItem"></div>')
            .css({ 'float': 'left' });

        $node.append(
            self.$('<a href="#"></a>')
                .css({ whiteSpace: 'nowrap' })
                .html(item.bolded_title || item.title)
                .attr('value', index)
                .click(function() {
                    self.accept(index);
                    return false;
                })
        );

        if (item.desc) {
            $node.append(
                self.$('<div></div>')
                    .html(item.bolded_desc)
                    .css('whiteSpace', 'nowrap')
            );
        }
        return $node
    };

    Lookahead.prototype.show = function () {
        var self = this;

        var lookahead = this.getLookahead();
        if (!lookahead.is(':visible')) {
            lookahead.fadeIn(function() {
                self.allowMouseClicks();
                if ($.isFunction(self.opts.onShow)) {
                    self.opts.onShow();
                }
            });
        }

        // IE6 iframe hack:
        // Enabling the select overlap breaks clicking on the lookahead if the
        // lookahead is inserted into a different window.
        // NOTE: We cannot have "zIndex:" here, otherwise elements in the
        // lookahead become unclickable and causes {bz: 2597}.
        if (window === this.window)
            this.lookahead.createSelectOverlap({ padding: 1 });
    };

    Lookahead.prototype.hide = function () {
        var lookahead = this.getLookahead();
        if (lookahead.is(':visible')) {
            lookahead.fadeOut();
        }
    };

    Lookahead.prototype.acceptInputValue = function() {
        var value = $(this.input).val();
        this.clearLookahead();

        if (this.opts.onAccept) {
            this.opts.onAccept.call(this.input, value, {});
        }
    };

    Lookahead.prototype.accept = function (i) {
        if (!i) i = 0; // treat undefined as 0
        var item;
        if (arguments.length) {
            item = this._items[i];
            this.select(item);
        }
        else if (this._selected) {
            // Check if we are displaying the last selected value
            if (this.displayAs(this._selected) == $(this.input).val()) {
                item = this._selected;
            }
        }

        var value = item ? item.value : $(this.input).val();

        this.clearLookahead();

        if (item.onAccept) {
            item.onAccept.call(this.input, value, item);
        }
        else if (this.opts.onAccept) {
            this.opts.onAccept.call(this.input, value, item);
        }
    }

    Lookahead.prototype.displayAs = function (item) {
        if (item && item.displayAs) {
            return item.displayAs;
        }
        else if ($.isFunction(this.opts.displayAs)) {
            return this.opts.displayAs(item);
        }
        else if (item) {
            return item.value;
        }
        else {
            return $(this.input).val();
        }
    }

    Lookahead.prototype.select = function (item, provisional) {
        this._selected = item;
        if (!provisional) {
            $(this.input).val(this.displayAs(item));
        }
    }
    
    Lookahead.prototype._highlight_element = function (el) {
        jQuery('li.selected', this.lookahead)
            .removeClass('selected')
            .css({ background: '' });
        el.addClass('selected').css({ background: SELECTED_COLOR });
    }

    Lookahead.prototype.select_element = function (el, provisional) {
        this._highlight_element(el);
        var value = el.find('a').attr('value');
        var item = this._items[value];
        this.select(item, provisional);
    }

    Lookahead.prototype.selectDown = function () {
        if (!this.lookahead) return;
        var el;
        if (jQuery('li.selected', this.lookahead).length) {
            el = jQuery('li.selected', this.lookahead).next('li');
        }
        if (! (el && el.length) ) {
            el = jQuery('li:first', this.lookahead);
        }
        this.select_element(el, false);
    };

    Lookahead.prototype.selectUp = function () {
        if (!this.lookahead) return;
        var el;
        if (jQuery('li.selected', this.lookahead).length) {
            el = jQuery('li.selected', this.lookahead).prev('li');
        }
        if (! (el && el.length) ) {
            el = jQuery('li:last', this.lookahead);
        }
        this.select_element(el, false);
    };

    Lookahead.prototype.clickCurrent = function () {
        if (!this.opts.requireMatch) {
            this.acceptInputValue();
        }
        else if (this._items.length) {
            var selitem = jQuery('li.selected a', this.lookahead);
            if (selitem.length && selitem.attr('value')) {
                this.accept(selitem.attr('value'));
            }
            else if (this._items.length == 1) {
                // Only one candidate - accept it
                this.accept(0);
            }
            else {
                var val = $(this.input).val();
                var fullMatchIndex = null;

                $.each(this._items, function(i) {
                    var item = this || {};
                    if (item.bolded_title == ('<b>'+item.title.replace(/</g, "&lt;").replace(/>/g, "&gt;") +'</b>')) {
                        if (fullMatchIndex) {
                            // Two or more full matches - do nothing
                            return;
                        }
                        fullMatchIndex = i;
                    }
                });

                // Only one full match - accept it
                if (fullMatchIndex != null) {
                    this.accept(fullMatchIndex);
                }
            }
        }
    };

    Lookahead.prototype.storeCache = function (val, data) {
        this._cache = this._cache || {};
        this._cache[val] = data;
        this._prevVal = val;
    }

    Lookahead.prototype.getCached = function (val) {
        this._cache = this._cache || {};

        if (this._cache[val]) {
            // We've already done this query, so just return this data
            return this.filterData(val, this._cache[val])
        }
        else if (this._prevVal) {
            var re = this.filterRE(this._prevVal);
            if (val.match(re)) {
                // filter the previous data, but only return if we still
                // have at least the minimum or if filtering the data made
                // no difference
                var cached = this._cache[this._prevVal];
                if (cached) {
                    filtered = this.filterData(val, cached)
                    var use_cache = cached.length == filtered.length
                                 || filtered.length >= this.opts.count;
                    if (use_cache) {
                        // save this for next time
                        this.storeCache(val, cached);
                        return filtered;
                    }
                }
            }
        }
        return [];
    };

    Lookahead.prototype.abort = function () {
        if (this.request) this.request.abort();
    };

    Lookahead.prototype.createFilterValue = function (val) {
        if (this.opts.filterValue) {
            return this.opts.filterValue(val);
        }
        else {
            var filter = FILTER_TYPES[this.opts.filterType];
            if (!filter) {
                throw new Error('invalid filterType: ' + this.opts.filterType);
            }
            return val.replace(/^(.*)$/, filter);
        }
    };

    Lookahead.prototype.onchange = function () {
        var self = this;
        if (this._loading_lookahead) {
            this._change_queued = true;
            return;
        }

        this._change_queued = false;

        var val = $(this.input).val();
        if (!val) {
            this.clearLookahead()
            return;
        }

        var cached = this.getCached(val);
        if (cached.length) {
            this.displayData(cached);
            return;
        }

        var url = typeof(this.opts.url) == 'function'
                ? this.opts.url() : this.opts.url;

        var params = this.opts.params;

        if (this.opts.fetchAll) {
            delete params.count;
        }
        else {
            params[this.opts.filterName] = this.createFilterValue(val);
        }

        this._loading_lookahead = true;
        this.request = $.ajax({
            url: url,
            data: params,
            cache: false,
            dataType: 'json',
            success: function (data) {
                self.storeCache(val, data);
                self._loading_lookahead = false;
                if (self._change_queued) {
                    self.onchange();
                    return;
                }
                self.displayData(
                    self.filterData(val, data)
                );
            },
            error: function (xhr, textStatus, errorThrown) {
                self._loading_lookahead = false;
                if (self._change_queued) {
                    self.onchange();
                    return;
                }
                var $error = self.$('<span></span>')
                    .addClass("st-suggestion-warning");
                self.$('<li></li>')
                    .append($error)
                    .appendTo(self.getLookaheadList());

                if (textStatus == 'parsererror') {
                    $error.html(loc("error.parsing-data"));
                }
                else if (self.opts.onError) {
                    var errorHandler = self.opts.onError[xhr.status]
                                    || self.opts.onError['default'];
                    if (errorHandler) {
                        if ($.isFunction(errorHandler)) {
                            $error.html(
                                errorHandler(xhr, textStatus, errorThrown)
                            );
                        }
                        else {
                            $error.html(errorHandler);
                        }
                    }
                }
                else {
                    $error.html(textStatus);
                }
                self.show();
            }
        });
    };

})(jQuery);
;
// BEGIN fades.js
(function($){

$.fn.fade = function(color, cb) {
    $(this).addClass('colorFaded').animate(
        { backgroundColor: color },
        function() {
            if (cb) cb();
            cb = null;
        }
    );
}

$.fn.yellowFade = function(cb) {
    $(this).fade('#FFC', cb);
}

$.fn.redFade = function(cb) {
    $(this).fade('#ECAAAA', cb);
}

$.fn.clearFades = function(cb) {
    if ($(this).hasClass('colorFaded')) {
        $(this).fade('white', function() {
            $(this).removeClass('colorFaded');
            $(this).clearFades(cb); // tail-recurse into the next branch...
        });
    }
    else if ($(this).find('.colorFaded').size()) {
        $(this).find('.colorFaded').fade('white', function() {
            $(this).find('.colorFaded').removeClass('colorFaded');
            $(this).clearFades(cb); // tail-recurse into the next branch...
        });
    }
    else {
        if (cb) cb();
        cb = null;
    }
}

})(jQuery);
;
// BEGIN loc.js
function loc() {
    if (typeof LocalizedStrings == 'undefined')
        LocalizedStrings = {};

    var locale = Socialtext.loc_lang;
    var dict = LocalizedStrings[locale] || LocalizedStrings['en'] || {};
    var str = arguments[0] || "";
    var l10n = dict[str];
    var nstr = "";

    if (locale == 'xx') {
        l10n = str.replace(/[A-Z]/g, 'X').replace(/[a-z]/g, 'x');
    }
    else if (locale == 'xq') {
        l10n = "«" + str + "»";
    }
    else if (locale == 'xr') {
        l10n = str.replace(/a/g, '4')
                  .replace(/e/g, '3')
                  .replace(/o/g, '0')
                  .replace(/t/g, '7')
                  .replace(/b/g, '8')
                  .replace(/qu4n7/g, 'quant')
                  .replace(/<4 hr3f/g, '<a href');
    }

    if (!l10n) {
        /* If the hash-lookup failed, convert " into \\\" and try again. */
        nstr = str.replace(/\"/g, "\\\"");
        l10n = dict[nstr];
        if (!l10n) {
            /* If the hash-lookup failed, convert [_1] into %1 and try again. */
            nstr = nstr.replace(/\[_(\d+)\]/g, "%$1");
            l10n = dict[nstr] || str;
        }
    }

    l10n = l10n.replace(/\\\"/g, "\"");

    /* Convert both %1 and [_1] style vars into the given arguments */
    for (var i = 1; i < arguments.length; i++) {
        var rx = new RegExp("\\[_" + i + "\\]", "g");
        var rx2 = new RegExp("%" + i + "", "g");
        l10n = l10n.replace(rx, arguments[i]);
        l10n = l10n.replace(rx2, arguments[i]);

        var quant = new RegExp("\\[(?:quant|\\*),_" + i + ",([^\\],]+)(?:,([^\\],]+))?(?:,([^\\]]+))?\\]");
        while (quant.exec(l10n)) {
            var num = arguments[i] || 0;
            if (num == 0 && RegExp.$3) { // Empty condition exists
                l10n = l10n.replace(quant, RegExp.$3);
            }
            else if (num == 1) {
                l10n = l10n.replace(quant, num + ' ' + RegExp.$1);
            }
            else {
                l10n = l10n.replace(quant, num + ' ' + (RegExp.$2 || (RegExp.$1 + 's')));
            }
        }
    }

    return l10n;
};

loc.all_widgets = function(){
    $(function(){
        $('span[data-loc_text]').each(function(){
            var $span = $(this);
            $span.text(loc($span.data('loc_text')));
        });
        $('input[data-loc_val]').each(function(){
            var $input = $(this);
            $input.val(loc($input.data('loc_val')));
        });
    });
};
;
// BEGIN jquery-json-1.3.js
/*
 * jQuery JSON Plugin
 * version: 1.0 (2008-04-17)
 *
 * This document is licensed as free software under the terms of the
 * MIT License: http://www.opensource.org/licenses/mit-license.php
 *
 * Brantley Harris technically wrote this plugin, but it is based somewhat
 * on the JSON.org website's http://www.json.org/json2.js, which proclaims:
 * "NO WARRANTY EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.", a sentiment that
 * I uphold.  I really just cleaned it up.
 *
 * It is also based heavily on MochiKit's serializeJSON, which is 
 * copywrited 2005 by Bob Ippolito.
 */
 
(function($) {   
    function toIntegersAtLease(n) 
    // Format integers to have at least two digits.
    {    
        return n < 10 ? '0' + n : n;
    }

    Date.prototype.toJSON = function(date)
    // Yes, it polutes the Date namespace, but we'll allow it here, as
    // it's damned usefull.
    {
        return this.getUTCFullYear()   + '-' +
             toIntegersAtLease(this.getUTCMonth()) + '-' +
             toIntegersAtLease(this.getUTCDate());
    };

    var escapeable = /["\\\x00-\x1f\x7f-\x9f]/g;
    var meta = {    // table of character substitutions
            '\b': '\\b',
            '\t': '\\t',
            '\n': '\\n',
            '\f': '\\f',
            '\r': '\\r',
            '"' : '\\"',
            '\\': '\\\\'
        };
        
    $.quoteString = function(string)
    // Places quotes around a string, inteligently.
    // If the string contains no control characters, no quote characters, and no
    // backslash characters, then we can safely slap some quotes around it.
    // Otherwise we must also replace the offending characters with safe escape
    // sequences.
    {
        if (escapeable.test(string))
        {
            return '"' + string.replace(escapeable, function (a) 
            {
                var c = meta[a];
                if (typeof c === 'string') {
                    return c;
                }
                c = a.charCodeAt();
                return '\\u00' + Math.floor(c / 16).toString(16) + (c % 16).toString(16);
            }) + '"';
        }
        return '"' + string + '"';
    };
    
    $.toJSON = function(o, compact)
    {
        var type = typeof(o);
        
        if (type == "undefined")
            return "undefined";
        else if (type == "number" || type == "boolean")
            return o + "";
        else if (o === null)
            return "null";
        
        // Is it a string?
        if (type == "string") 
        {
            return $.quoteString(o);
        }
        
        // Does it have a .toJSON function?
        if (type == "object" && typeof o.toJSON == "function") 
            return o.toJSON(compact);
        
        // Is it an array?
        if (type != "function" && typeof(o.length) == "number") 
        {
            var ret = [];
            for (var i = 0; i < o.length; i++) {
                ret.push( $.toJSON(o[i], compact) );
            }
            if (compact)
                return "[" + ret.join(",") + "]";
            else
                return "[" + ret.join(", ") + "]";
        }
        
        // If it's a function, we have to warn somebody!
        if (type == "function") {
            throw new TypeError("Unable to convert object of type 'function' to json.");
        }
        
        // It's probably an object, then.
        var ret = [];
        for (var k in o) {
            var name;
            type = typeof(k);
            
            if (type == "number")
                name = '"' + k + '"';
            else if (type == "string")
                name = $.quoteString(k);
            else
                continue;  //skip non-string or number keys
            
            var val = $.toJSON(o[k], compact);
            if (typeof(val) != "string") {
                // skip non-serializable values
                continue;
            }
            
            if (compact)
                ret.push(name + ":" + val);
            else
                ret.push(name + ": " + val);
        }
        return "{" + ret.join(", ") + "}";
    };
    
    $.compactJSON = function(o)
    {
        return $.toJSON(o, true);
    };
    
    $.evalJSON = function(src)
    // Evals JSON that we know to be safe.
    {
        return eval("(" + src + ")");
    };
    
    $.secureEvalJSON = function(src)
    // Evals JSON in a way that is *more* secure.
    {
        var filtered = src;
        filtered = filtered.replace(/\\["\\\/bfnrtu]/g, '@');
        filtered = filtered.replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g, ']');
        filtered = filtered.replace(/(?:^|:|,)(?:\s*\[)+/g, '');
        
        if (/^[\],:{}\s]*$/.test(filtered))
            return eval("(" + src + ")");
        else
            throw new SyntaxError("Error parsing JSON, source is not valid.");
    };
})(jQuery);
;
// BEGIN Jemplate Runtime
/*------------------------------------------------------------------------------
Jemplate - Template Toolkit for JavaScript

DESCRIPTION - This module provides the runtime JavaScript support for
compiled Jemplate templates.

AUTHOR - Ingy döt Net <ingy@cpan.org>

Copyright 2006,2008 Ingy döt Net.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
------------------------------------------------------------------------------*/

//------------------------------------------------------------------------------
// Main Jemplate class
//------------------------------------------------------------------------------

if (typeof Jemplate == 'undefined') {
    var Jemplate = function() {
        this.init.apply(this, arguments);
    };
}

Jemplate.VERSION = '0.22';

Jemplate.process = function() {
    var jemplate = new Jemplate(Jemplate.prototype.config);
    return jemplate.process.apply(jemplate, arguments);
}

;(function(){

if (! Jemplate.templateMap)
    Jemplate.templateMap = {};

var proto = Jemplate.prototype = {};

proto.config = {
    AUTO_RESET: true,
    BLOCKS: {},
    CONTEXT: null,
    DEBUG_UNDEF: false,
    DEFAULT: null,
    ERROR: null,
    EVAL_JAVASCRIPT: false,
    GLOBAL : true,
	SCOPE : this,
    FILTERS: {},
    INCLUDE_PATH: [''],
    INTERPOLATE: false,
    OUTPUT: null,
    PLUGINS: {},
    POST_PROCESS: [],
    PRE_PROCESS: [],
    PROCESS: null,
    RECURSION: false,
    STASH: null,
    TOLERANT: null,
    VARIABLES: {},
    WRAPPER: []
};

proto.defaults = {
    AUTO_RESET: true,
    BLOCKS: {},
    CONTEXT: null,
    DEBUG_UNDEF: false,
    DEFAULT: null,
    ERROR: null,
    EVAL_JAVASCRIPT: false,
    GLOBAL : true,
	SCOPE : this,
    INCLUDE_PATH: [''],
    INTERPOLATE: false,
    OUTPUT: null,
    PLUGINS: {},
    POST_PROCESS: [],
    PRE_PROCESS: [],
    PROCESS: null,
    RECURSION: false,
    STASH: null,
    TOLERANT: null,
    VARIABLES: {},
    WRAPPER: []
};


Jemplate.init = function(config) {
 
    Jemplate.prototype.config = config || {};
    
    for (var i in Jemplate.prototype.defaults) {
        if(typeof Jemplate.prototype.config[i] == "undefined") {
            Jemplate.prototype.config[i] = Jemplate.prototype.defaults[i];
        }
    }
}

proto.init = function(config) {
    
    this.config = config || {};
    
    for (var i in Jemplate.prototype.defaults) {
        if(typeof this.config[i] == "undefined") {
            this.config[i] = Jemplate.prototype.defaults[i];
        }
    }
}

proto.process = function(template, data, output) {
    var context = this.config.CONTEXT || new Jemplate.Context();
    context.config = this.config;

    context.stash = new Jemplate.Stash(this.config.STASH, this.config);

    context.__filter__ = new Jemplate.Filter();
    context.__filter__.config = this.config;

    context.__plugin__ = new Jemplate.Plugin();
    context.__plugin__.config = this.config;

    var result;

    var proc = function(input) {
        try {
            if (typeof context.config.PRE_PROCESS == 'string') context.config.PRE_PROCESS = [context.config.PRE_PROCESS];                
            for (var i = 0; i < context.config.PRE_PROCESS.length; i++) {
                context.process(context.config.PRE_PROCESS[i]);
            }
            
            result = context.process(template, input);
            
            if (typeof context.config.POST_PROCESS == 'string') context.config.PRE_PROCESS = [context.config.POST_PROCESS];
            for (i = 0; i < context.config.POST_PROCESS.length; i++) {
                context.process(context.config.POST_PROCESS[i]);
            }
        }
        catch(e) {
            if (! String(e).match(/Jemplate\.STOP\n/))
                throw(e);
            result = e.toString().replace(/Jemplate\.STOP\n/, '');
        }

        if (typeof output == 'undefined')
            return result;
        if (typeof output == 'function') {
            output(result);
            return null;
        }
        if (typeof(output) == 'string' || output instanceof String) {
            if (output.match(/^#[\w\-]+$/)) {
                var id = output.replace(/^#/, '');
                var element = document.getElementById(id);
                if (typeof element == 'undefined')
                    throw('No element found with id="' + id + '"');
                element.innerHTML = result;
                return null;
            }
        }
        else {
            output.innerHTML = result;
            return null;
        }

        throw("Invalid arguments in call to Jemplate.process");

        return 1;
    }

    if (typeof data == 'function')
        data = data();
    else if (typeof data == 'string') {
//        Jemplate.Ajax.get(data, function(r) { proc(Jemplate.JSON.parse(r)) });
        var url = data;
        Jemplate.Ajax.processGet(url, function(data) { proc(data) });
        return null;
    }

    return proc(data);
}

//------------------------------------------------------------------------------
// Jemplate.Context class
//------------------------------------------------------------------------------
if (typeof Jemplate.Context == 'undefined')
    Jemplate.Context = function() {};

proto = Jemplate.Context.prototype;

proto.include = function(template, args) {
    return this.process(template, args, true);
}

proto.process = function(template, args, localise) {
    if (localise)
        this.stash.clone(args);
    else
        this.stash.update(args);
    var func = Jemplate.templateMap[template];
    if (typeof func == 'undefined')
        throw('No Jemplate template named "' + template + '" available');
    var output = func(this);
    if (localise)
        this.stash.declone();
    return output;
}

proto.set_error = function(error, output) {
    this._error = [error, output];
    return error;
}

proto.plugin = function(name, args) {
    if (typeof name == 'undefined')
        throw "Unknown plugin name ':" + name + "'";

    // The Context object (this) is passed as the first argument to the plugin.
	var func = eval(name);
    return new func(this, args);
}

proto.filter = function(text, name, args) {
    if (name == 'null')
        name = "null_filter";
    if (typeof this.__filter__.filters[name] == "function")
        return this.__filter__.filters[name](text, args, this);
    else
        throw "Unknown filter name ':" + name + "'";
}

//------------------------------------------------------------------------------
// Jemplate.Plugin class
//------------------------------------------------------------------------------
if (typeof Jemplate.Plugin == 'undefined') {
    Jemplate.Plugin = function() { };
}

proto = Jemplate.Plugin.prototype;

proto.plugins = {};

//------------------------------------------------------------------------------
// Jemplate.Filter class
//------------------------------------------------------------------------------
if (typeof Jemplate.Filter == 'undefined') {
    Jemplate.Filter = function() { };
}

proto = Jemplate.Filter.prototype;

proto.filters = {};

proto.filters.null_filter = function(text) {
    return '';
}

proto.filters.upper = function(text) {
    return text.toUpperCase();
}

proto.filters.lower = function(text) {
    return text.toLowerCase();
}

proto.filters.ucfirst = function(text) {
    var first = text.charAt(0);
    var rest = text.substr(1);
    return first.toUpperCase() + rest;
}

proto.filters.lcfirst = function(text) {
    var first = text.charAt(0);
    var rest = text.substr(1);
    return first.toLowerCase() + rest;
}

proto.filters.trim = function(text) {
    return text.replace( /^\s+/g, "" ).replace( /\s+$/g, "" );
}

proto.filters.collapse = function(text) {
    return text.replace( /^\s+/g, "" ).replace( /\s+$/g, "" ).replace(/\s+/, " ");
}

proto.filters.html = function(text) {
    text = text.replace(/&/g, '&amp;');
    text = text.replace(/</g, '&lt;');
    text = text.replace(/>/g, '&gt;');
    text = text.replace(/"/g, '&quot;'); // " end quote for emacs
    return text;
}

proto.filters.html_para = function(text) {
    var lines = text.split(/(?:\r?\n){2,}/);
    return "<p>\n" + lines.join("\n</p>\n\n<p>\n") + "</p>\n";
}

proto.filters.html_break = function(text) {
    return text.replace(/(\r?\n){2,}/g, "$1<br />$1<br />$1");
}

proto.filters.html_line_break = function(text) {
    return text.replace(/(\r?\n)/g, "$1<br />$1");
}

proto.filters.uri = function(text) {
     return encodeURIComponent(text);
}
 
proto.filters.url = function(text) {
    return encodeURI(text);
}

proto.filters.indent = function(text, args) {
    var pad = args[0];
    if (! text) return null;
    if (typeof pad == 'undefined')
        pad = 4;

    var finalpad = '';
    if (typeof pad == 'number' || String(pad).match(/^\d$/)) {
        for (var i = 0; i < pad; i++) {
            finalpad += ' ';
        }
    } else {
        finalpad = pad;
    }
    var output = text.replace(/^/gm, finalpad);
    return output;
}

proto.filters.truncate = function(text, args) {
    var len = args[0];
    if (! text) return null;
    if (! len)
        len = 32;
    // This should probably be <=, but TT just uses <
    if (text.length < len)
        return text;
    var newlen = len - 3;
    return text.substr(0,newlen) + '...';
}

proto.filters.repeat = function(text, iter) {
    if (! text) return null;
    if (! iter || iter == 0)
        iter = 1;
    if (iter == 1) return text

    var output = text;
    for (var i = 1; i < iter; i++) {
        output += text;
    }
    return output;
}

proto.filters.replace = function(text, args) {
    if (! text) return null;
    var re_search = args[0];
    var text_replace = args[1];
    if (! re_search)
        re_search = '';
    if (! text_replace)
        text_replace = '';
    var re = new RegExp(re_search, 'g');
    return text.replace(re, text_replace);
}

//------------------------------------------------------------------------------
// Jemplate.Stash class
//------------------------------------------------------------------------------
if (typeof Jemplate.Stash == 'undefined') {
    Jemplate.Stash = function(stash, config) {
        this.__config__ = config;
		
		this.data = {
			GLOBAL : this.__config__.SCOPE			
		};
		this.LOCAL_ANCHOR = {};
		this.data.LOCAL = this.LOCAL_ANCHOR;
		
		this.update(stash);
    };
}

proto = Jemplate.Stash.prototype;

proto.clone = function(args) {
    var data = this.data;
    this.data = {
		GLOBAL : this.__config__.SCOPE
	};
	this.data.LOCAL = this.LOCAL_ANCHOR;
    this.update(data);
    this.update(args);
    this.data._PARENT = data;
}

proto.declone = function(args) {
    this.data = this.data._PARENT || this.data;
}

proto.update = function(args) {
    if (typeof args == 'undefined') return;
    for (var key in args) {
        if (key != 'GLOBAL' && key != 'LOCAL') {
	        this.set(key, args[key]);
		}
    }
}

proto.get = function(ident, args) {
    var root = this.data;
    
    var value;
    
    if ( (ident instanceof Array) || (typeof ident == 'string' && /\./.test(ident) ) ) {
        
        if (typeof ident == 'string') {
            ident = ident.split('.');
            var newIdent = [];
            for (var i = 0; i < ident.length; i++) {
                newIdent.push(ident.replace(/\(.*$/,''));
                newIdent.push(0);
            }
            ident = newIdent;
        }
        
        for (var i = 0; i < ident.length; i += 2) {
            var dotopArgs = ident.slice(i, i+2);
            dotopArgs.unshift(root);
            value = this._dotop.apply(this, dotopArgs);
            if (typeof value == 'undefined')
                break;
            root = value;
        }
    }
    else {
        value = this._dotop(root, ident, args);
    }

    if (typeof value == 'undefined' || value == null) {
        if (this.__config__.DEBUG_UNDEF)
            throw("undefined value found while using DEBUG_UNDEF");
        value = '';
    }

    return value;
}



proto.set = function(ident, value, set_default) {
    
    var root, result, error;
    
    root = this.data;
    
    while (true) {
        if ( (ident instanceof Array) || (typeof ident == 'string' && /\./.test(ident) ) ) {
            
            if (typeof ident == 'string') {
                ident = ident.split('.');
                var newIdent = [];
                for (var i = 0; i < ident.length; i++) {
                    newIdent.push(ident.replace(/\(.*$/,''));
                    newIdent.push(0);
                }
                ident = newIdent;
            }
            
            for (var i = 0; i < ident.length - 2; i += 2) {
                var dotopArgs = ident.slice(i, i+2);
                dotopArgs.unshift(root);
                dotopArgs.push(1);
                result = this._dotop.apply(this, dotopArgs);
                if (typeof value == 'undefined')
                    break;
                root = result;
            }
            
            var assignArgs = ident.slice(ident.length-2, ident.length);
            assignArgs.unshift(root);
            assignArgs.push(value);
            assignArgs.push(set_default);
            
            
            result = this._assign.apply(this, assignArgs);
        } else {
            result = this._assign(root, ident, 0, value, set_default);
        }
        break;
    }
    
    return (typeof result != 'undefined') ? result : '';
}



proto._dotop = function(root, item, args, lvalue) {    
    if (root == this.LOCAL_ANCHOR) root = this.data;
	var atroot = root == this.data;
    
    var value,result = undefined;
    
   	var is_function_call = args instanceof Array;
   	
   	args = args || [];
    
    if (typeof root == 'undefined' || typeof item == 'undefined' || typeof item == 'string' && item.match(/^[\._]/)) {
        return undefined;
    }


    //root is complex object, not scalar
    if (atroot || (root instanceof Object && !(root instanceof Array)) || root == this.data.GLOBAL) {
        
		if (typeof root[item] != 'undefined' && root[item] != null && (!is_function_call || !this.hash_functions[item])) { //consider undefined == null
            if (typeof root[item] == 'function') {
                result = root[item].apply(root,args);
            } else {
                return root[item];
            }
        } else if (lvalue) {
            return root[item] = {};
        } else if (this.hash_functions[item] && !atroot || item == 'import') {
            args.unshift(root);
            result = this.hash_functions[item].apply(this,args);
        } else if (item instanceof Array) {
            result = {};
            
            for (var i = 0; i < item.length; i++) result[item[i]] = root[item[i]];
            return result;
        }
    } else if (root instanceof Array) {
        if (this.list_functions[item]) {
            args.unshift(root);
            result = this.list_functions[item].apply(this,args);
        } else if (typeof item == 'string' && /^-?\d+$/.test(item) || typeof item == 'number' ) {
            if (typeof root[item] != 'function') return root[item];
            result = root[item].apply(this, args);
        } else if (item instanceof Array) {
            for (var i = 0; i < item.length; i++) result.push(root[item[i]]);
            return result;
        }
    } else if (this.string_functions[item] && !lvalue) {
        args.unshift(root);
        result = this.string_functions[item].apply(this, args);
    } else if (this.list_functions[item] && !lvalue) {
        args.unshift([root]);
        result = this.list_functions[item].apply(this,args);
    } else {
        result = undefined;
    }
    
    
    if (result instanceof Array) {
		if (typeof result[0] == 'undefined' && typeof result[1] != 'undefined') {
	        throw result[1];
	    }
	}
    
    return result;

}


proto._assign = function(root, item, args, value, set_default) {
    var atroot = root == this.data;
    var result;
    
    args = args || [];
    
    if (typeof root == 'undefined' || typeof item == 'undefined' || typeof item == 'string' && item.match(/^[\._]/)) {
        return undefined;
    }
    
    if (atroot || root.constructor == Object || root == this.data.GLOBAL) {
		
		if (root == this.LOCAL_ANCHOR) root = this.data;
			 
		if (!(set_default && typeof root[item] != 'undefined')) {
            if (atroot && item == 'GLOBAL') throw "Attempt to modify GLOBAL access modifier"
			if (atroot && item == 'LOCAL') throw "Attempt to modify LOCAL access modifier"
			
			return root[item] = value;
        } 
    } else if ((root instanceof Array) && (typeof item == 'string' && /^-?\d+$/.test(item) || typeof item == 'number' )) {
        if (!(set_default && typeof root[item] != 'undefined')) {
            return root[item] = value;
        }
    } else if ( (root.constructor != Object) && (root instanceof Object) ) {
        try {
            result = root[item].apply(root,args);
        } catch (e) {
        }
    } else {
        throw 'dont know how to assign to [' + root + '.' + item +']';
    }
    
    return undefined;
}


proto.string_functions = {};

// typeof
proto.string_functions['typeof'] = function(value) {
    return typeof value;
}

// chunk(size)     negative size chunks from end
proto.string_functions.chunk = function(string, size) {
    //var size = args;
    var list = new Array();
    if (! size)
        size = 1;
    if (size < 0) {
        size = 0 - size;
        for (var i = string.length - size; i >= 0; i = i - size)
            list.unshift(string.substr(i, size));
        if (string.length % size)
            list.unshift(string.substr(0, string.length % size));
    }
    else
        for (i = 0; i < string.length; i = i + size)
            list.push(string.substr(i, size));
    return list;
}

// defined         is value defined?
proto.string_functions.defined = function(string) {
    return 1;
}

// hash            treat as single-element hash with key value
proto.string_functions.hash = function(string) {
    return { 'value': string };
}

// length          length of string representation
proto.string_functions.length = function(string) {
    return string.length;
}

// list            treat as single-item list
proto.string_functions.list = function(string) {
    return [ string ];
}

// match(re)       get list of matches
proto.string_functions.match = function(string, re, modifiers) {
    var regexp = new RegExp(re, modifiers == undefined ? 'g' : modifiers);
    var list = string.match(regexp);
    return list;
}

// repeat(n)       repeated n times
proto.string_functions.repeat = function(string, args) {
    var n = args || 1;
    var output = '';
    for (var i = 0; i < n; i++) {
        output += string;
    }
    return output;
}

// replace(re, sub, global)    replace instances of re with sub
proto.string_functions.replace = function(string, re, sub, modifiers) {
    var regexp = new RegExp(re, modifiers == undefined ? 'g' : modifiers);    
    if (! sub) sub  = '';

    return string.replace(regexp, sub);
}

// search(re)      true if value matches re
proto.string_functions.search = function(string, re) {
    var regexp = new RegExp(re);
    return (string.search(regexp) >= 0) ? 1 : 0;
}

// size            returns 1, as if a single-item list
proto.string_functions.size = function(string) {
    return 1;
}

// split(re)       split string on re
proto.string_functions.split = function(string, re) {
    var regexp = new RegExp(re);
    var list = string.split(regexp);
    return list;
}



proto.list_functions = {};

// typeof
proto.list_functions['typeof'] = function(list) {
    return 'array';
};


proto.list_functions.list = function(list) {
    return list;
};

proto.list_functions.join = function(list, str) {
    return list.join(str);
};

proto.list_functions.sort = function(list,key) {
    if( typeof(key) != 'undefined' && key != "" ) {
        // we probably have a list of hashes
        // and need to sort based on hash key
        return list.sort(
            function(a,b) {
                if( a[key] == b[key] ) {
                    return 0;
                }
                else if( a[key] > b[key] ) {
                    return 1;
                }
                else {
                    return -1;
                }
            }
        );
    }
    return list.sort();
}

proto.list_functions.nsort = function(list) {
    return list.sort(function(a, b) { return (a-b) });
}

proto.list_functions.grep = function(list, re) {
    var regexp = new RegExp(re);
    var result = [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].match(regexp))
            result.push(list[i]);
    }
    return result;
}

proto.list_functions.unique = function(list) {
    var result = [];
    var seen = {};
    for (var i = 0; i < list.length; i++) {
        var elem = list[i];
        if (! seen[elem])
            result.push(elem);
        seen[elem] = true;
    }
    return result;
}

proto.list_functions.reverse = function(list) {
    var result = [];
    for (var i = list.length - 1; i >= 0; i--) {
        result.push(list[i]);
    }
    return result;
}

proto.list_functions.merge = function(list /*, ... args */) {
    var result = [];
    var push_all = function(elem) {
        if (elem instanceof Array) {
            for (var j = 0; j < elem.length; j++) {
                result.push(elem[j]);
            }
        }
        else {
            result.push(elem);
        }
    }
    push_all(list);
    for (var i = 1; i < arguments.length; i++) {
        push_all(arguments[i]);
    }
    return result;
}

proto.list_functions.slice = function(list, start, end) {
    // To make it like slice in TT
    // See rt53453
    if ( end == -1 ) {
        return list.slice( start );
    }
    return list.slice( start, end + 1 );
}

proto.list_functions.splice = function(list /*, ... args */ ) {
    var args = Array.prototype.slice.call(arguments);
    args.shift();
    
    return list.splice.apply(list,args);
}

proto.list_functions.push = function(list, value) {
    list.push(value);
    return list;
}

proto.list_functions.pop = function(list) {
    return list.pop();
}

proto.list_functions.unshift = function(list, value) {
    list.unshift(value);
    return list;
}

proto.list_functions.shift = function(list) {
    return list.shift();
}

proto.list_functions.first = function(list) {
    return list[0];
}

proto.list_functions.size = function(list) {
    return list.length;
}

proto.list_functions.max = function(list) {
    return list.length - 1;
}

proto.list_functions.last = function(list) {
    return list.slice(-1);
}

proto.hash_functions = {};

// typeof
proto.hash_functions['typeof'] = function(hash) {
    return 'object';
};


// each            list of alternating keys/values
proto.hash_functions.each = function(hash) {
    var list = new Array();
    for ( var key in hash )
        list.push(key, hash[key]);
    return list;
}

// exists(key)     does key exist?
proto.hash_functions.exists = function(hash, key) {
    return ( typeof( hash[key] ) == "undefined" ) ? 0 : 1;
}

// import(hash2)   import contents of hash2
// import          import into current namespace hash
proto.hash_functions['import'] = function(hash, hash2) {    
    for ( var key in hash2 )
        hash[key] = hash2[key];
    return '';
}

// keys            list of keys
proto.hash_functions.keys = function(hash) {
    var list = new Array();
    for ( var key in hash )
        list.push(key);
    return list;
}

// list            returns alternating key, value
proto.hash_functions.list = function(hash, what) {
    //var what = '';
    //if ( args )
        //what = args[0];

    var list = new Array();
    var key;
    if (what == 'keys')
        for ( key in hash )
            list.push(key);
    else if (what == 'values')
        for ( key in hash )
            list.push(hash[key]);
    else if (what == 'each')
        for ( key in hash )
            list.push(key, hash[key]);
    else
        for ( key in hash )
            list.push({ 'key': key, 'value': hash[key] });

    return list;
}

// nsort           keys sorted numerically
proto.hash_functions.nsort = function(hash) {
    var list = new Array();
    for (var key in hash)
        list.push(key);
    return list.sort(function(a, b) { return (a-b) });
}

// item           return a value by key
proto.hash_functions.item = function(hash, key) {
    return hash[key];
}

// size            number of pairs
proto.hash_functions.size = function(hash) {
    var size = 0;
    for (var key in hash)
        size++;
    return size;
}


// sort            keys sorted alphabetically
proto.hash_functions.sort = function(hash) {
    var list = new Array();
    for (var key in hash)
        list.push(key);
    return list.sort();
}

// values          list of values
proto.hash_functions.values = function(hash) {
    var list = new Array();
    for ( var key in hash )
        list.push(hash[key]);
    return list;
}

proto.hash_functions.pairs = function(hash) {
    var list = new Array();
    var keys = new Array();
    for ( var key in hash ) {
        keys.push( key );
    }
    keys.sort();
    for ( var key in keys ) {
        key = keys[key]
        list.push( { 'key': key, 'value': hash[key] } );
    }
    return list;
}

//  delete
proto.hash_functions.remove = function(hash, key) {
    return delete hash[key];
}
proto.hash_functions['delete'] = proto.hash_functions.remove;

//------------------------------------------------------------------------------
// Jemplate.Iterator class
//------------------------------------------------------------------------------
if (typeof Jemplate.Iterator == 'undefined') {
    Jemplate.Iterator = function(object) {
        if( object instanceof Array ) {
            this.object = object;
            this.size = object.length;
            this.max  = this.size -1;
        }
        else if ( object instanceof Object ) {
            this.object = object;
            var object_keys = new Array;
            for( var key in object ) {
                object_keys[object_keys.length] = key;
            }
            this.object_keys = object_keys.sort();
            this.size = object_keys.length;
            this.max  = this.size -1;
        } else if (typeof object == 'undefined' || object == null || object == '') {
            this.object = null;
            this.max  = -1;
        }
    }
}

proto = Jemplate.Iterator.prototype;

proto.get_first = function() {
    this.index = 0;
    this.first = 1;
    this.last  = 0;
    this.count = 1;
    return this.get_next(1);
}

proto.get_next = function(should_init) {
    var object = this.object;
    var index;
    if( typeof(should_init) != 'undefined' && should_init ) {
        index = this.index;
    } else {
        index = ++this.index;
        this.first = 0;
        this.count = this.index + 1;
        if( this.index == this.size -1 ) {
            this.last = 1;
        }
    }
    if (typeof object == 'undefined')
        throw('No object to iterate');
    if( this.object_keys ) {
        if (index < this.object_keys.length) {
            this.prev = index > 0 ? this.object_keys[index - 1] : "";
            this.next = index < this.max ? this.object_keys[index + 1] : "";
            return [this.object_keys[index], false];
        }
    } else {
        if (index <= this.max) {
            this.prev = index > 0 ? object[index - 1] : "";
            this.next = index < this.max ? object[index +1] : "";
            return [object[index], false];
        }
    }
    return [null, true];
}

var stubExplanation = "stub that doesn't do anything. Try including the jQuery, YUI, or XHR option when building the runtime";

Jemplate.Ajax = {

    get: function(url, callback) {
        throw("This is a Jemplate.Ajax.get " + stubExplanation);
    },

    processGet: function(url, callback) {
        throw("This is a Jemplate.Ajax.processGet " + stubExplanation);
    },

    post: function(url, callback) {
        throw("This is a Jemplate.Ajax.post " + stubExplanation);
    }

};

Jemplate.JSON = {

    parse: function(decodeValue) {
        throw("This is a Jemplate.JSON.parse " + stubExplanation);
    },

    stringify: function(encodeValue) {
        throw("This is a Jemplate.JSON.stringify " + stubExplanation);
    }

};

}());

;
// BEGIN JemplatePlugin/*.js
window.decorate = function () {};
Jemplate.Filter.prototype.filters.decorate = function(text, decorator) {
    return text;
}

// BEGIN JemplatePlugin/*.js
Jemplate.Filter.prototype.filters.html_encode = function(string) {
    return string
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

// BEGIN JemplatePlugin/*.js
// Port of label_ellipsis.pm
Jemplate.Filter.prototype.filters.label_ellipsis = function(text, length) {
    var ellipsis = '...';
    if (!length) length = 32;
    if (text.length <= length) return text;
    if (0 == length) return ellipsis;

    var new_text = '';
    var parts = text.split(' ');

    $.each(parts, function(i, part) {
        if (new_text.length + part.length + ellipsis.length > length)
            return false; // we're done
        new_text += part + ' ';
    });
    if (parts.length && new_text.length == 0) {
        new_text = parts[0].substr(0, length);
    }

    new_text = new_text.replace(/ *$/, '');
    return new_text + ellipsis;
};

;
// BEGIN Socialtext-Container/madlibs.js
function updateTimestamps(containerselector, relorigselector, reltargetselector)
{
    jQuery(containerselector).each(
        function(index, item) {
            var timestamp=jQuery(relorigselector, item).text();
            var then = new Date();
            then.setISO8601(timestamp);
            jQuery(reltargetselector, item).text(getAgoString(then));
        }
    );
}


// The following 2 functions borrowed from http://delete.me.uk/2005/03/iso8601.html
Date.prototype.setISO8601 = function (string) {
    var regexp = "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" +
        "([T ]([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?" +
        "(Z|(([-+])([0-9]{1,2})(?::([0-9]{2}))?))?)?)?)?";
    var d = string.match(new RegExp(regexp));

    var offset = 0;
    var date = new Date(d[1], 0, 1);

    if (d[3]) { date.setMonth(d[3] - 1); }
    if (d[5]) { date.setDate(d[5]); }
    if (d[7]) { date.setHours(d[7]); }
    if (d[8]) { date.setMinutes(d[8]); }
    if (d[10]) { date.setSeconds(d[10]); }
    if (d[12]) { date.setMilliseconds(Number("0." + d[12]) * 1000); }
    if (d[14]) {
        offset = (Number(d[16] || 0) * 60) + Number(d[17] || 0);
        offset *= ((d[15] == '-') ? 1 : -1);
    }

    offset -= date.getTimezoneOffset();
    var time = (Number(date) + (offset * 60 * 1000));
    this.setTime(Number(time));
}

Date.prototype.toISO8601String = function (format, offset) {
    /* accepted values for the format [1-6]:
     1 Year:
       YYYY (eg 1997)
     2 Year and month:
       YYYY-MM (eg 1997-07)
     3 Complete date:
       YYYY-MM-DD (eg 1997-07-16)
     4 Complete date plus hours and minutes:
       YYYY-MM-DDThh:mmTZD (eg 1997-07-16T19:20+01:00)
     5 Complete date plus hours, minutes and seconds:
       YYYY-MM-DDThh:mm:ssTZD (eg 1997-07-16T19:20:30+01:00)
     6 Complete date plus hours, minutes, seconds and a decimal
       fraction of a second
       YYYY-MM-DDThh:mm:ss.sTZD (eg 1997-07-16T19:20:30.45+01:00)
    */
    if (!format) { var format = 6; }
    if (!offset) {
        var offset = 'Z';
        var date = this;
    } else {
        var d = offset.match(/([-+])([0-9]{2}):([0-9]{2})/);
        var offsetnum = (Number(d[2]) * 60) + Number(d[3]);
        offsetnum *= ((d[1] == '-') ? -1 : 1);
        var date = new Date(Number(Number(this) + (offsetnum * 60000)));
    }

    var zeropad = function (num) { return ((num < 10) ? '0' : '') + num; }

    var str = "";
    str += date.getUTCFullYear();
    if (format > 1) { str += "-" + zeropad(date.getUTCMonth() + 1); }
    if (format > 2) { str += "-" + zeropad(date.getUTCDate()); }
    if (format > 3) {
        str += "T" + zeropad(date.getUTCHours()) +
               ":" + zeropad(date.getUTCMinutes());
    }
    if (format > 5) {
        var secs = Number(date.getUTCSeconds() + "." +
                   ((date.getUTCMilliseconds() < 100) ? '0' : '') +
                   zeropad(date.getUTCMilliseconds()));
        str += ":" + zeropad(secs);
    } else if (format > 4) { str += ":" + zeropad(date.getUTCSeconds()); }

    if (format > 3) { str += offset; }
    return str;
}

function best_full_name(person) {
    if (person['best_full_name'])
        return person['best_full_name'];

    if ((person['first_name'] != undefined) && 
        (person['last_name'] != undefined)) 
    {
        return person['first_name'] + " " + person['last_name'];
    }
    else {
        return person['name'].split('@')[0];
    }
}

function html_escape(text) {
    // XXX: surely we can use some javascript lib's version of this hack
    text = text.replace(/&/g,'&amp;');
    text = text.replace(/</g,'&lt;');
    text = text.replace(/>/g,'&gt;');
    return text;
}

function a_tag(link, text, clazz) {
    if (clazz == null) clazz = "";
    return '<a class="'+clazz+'"' +
            ' href="'+link+'">'+html_escape(text)+'</a>';
}

function linked_person_tag(evt, tag_name) { 
    return a_tag('/?action=people;tag='+encodeURIComponent(tag_name), tag_name);
}

function linked_page_tag(evt, tag_name) { 
    var ws_name = evt.page.workspace_name;
    var link_base = 'index.cgi?action=category_display;category=';
    return a_tag('/' + ws_name + '/' + link_base + encodeURIComponent(tag_name), tag_name, 'tag');
}

function linked_person(evt, person) {
    var bfn = best_full_name(person);
    return Number(person.profile_is_visible) ? a_tag('/?profile/' + person.id, bfn, 'person') : bfn;
}

function context_summary(evt, context) {
    return context.summary;
}

function linked_page(evt, page) { 
    var pg_id = page.id;
    var pg_name = page.name;
    var ws_name = page.workspace_name;
    var ws_title = page.workspace_title;
    var page = a_tag('/'+ws_name+'/index.cgi?'+pg_id, pg_name, 'object');
    var ws = a_tag('/'+ws_name+'/index.cgi', ws_title, undefined);
    return page + ' in ' + ws;
}

var page_madlib_constructors = {
    'view': {
        'sentence': "%(actor)s viewed %(page)s",
        'transformer': {}
    },
    'edit_save': {
        'sentence': "%(actor)s edited %(page)s",
        'transformer': {}
    },
    'duplicate': {
        'sentence': "%(actor)s duplicated %(page)s",
        'transformer': {}
    },
    'rename': {
        'sentence': "%(actor)s renamed  %(page)s",
        'transformer': {}
    },
    'delete': {
        'sentence': "%(actor)s deleted %(page)s",
        'transformer': {}
    },
    'comment': {
        'sentence': "%(actor)s commented on %(page)s, saying %(context)s",
        'transformer': {
            'context': context_summary
        }
    },
    'tag_add': {
        'sentence': "%(actor)s tagged %(page)s as %(tag_name)s",
        'transformer': {
            'tag_name': linked_page_tag
        }
    },
    'tag_delete': {
        'sentence': "%(actor)s removed tag %(tag_name)s from %(page)s",
        'transformer': {
            'tag_name': linked_page_tag
        }
    },

    'comment:convo': {
        // comment summaries don't show up in my convos feed
        'sentence': "%(actor)s commented on %(page)s",
        'transformer': {}
    },
    'tag_add:convo': {
        // tag names don't show up in my convos feed
        'sentence': "%(actor)s tagged %(page)s",
        'transformer': {}
    },
    'upload_file:convo': {
        'sentence': "%(actor)s uploaded a file to %(page)s",
        'transformer': {}
    },
    'watch_add': {
        'sentence': "%(actor)s is now following %(page).",
        'transformer': {}
    },
    'watch_delete': {
        'sentence': "%(actor)s has stopped following %(page).",
        'transformer': {}
    },

    'default': {
        'sentence': "%(actor)s performed action '%(action)s' on %(page)s",
        'transformer': {}
    }
}

var person_madlib_constructors = {
    'edit_save': {
        'sentence': "%(actor)s edited %(person)s's profile",
        'transformer': {}
    },
    'tag_add': {
        'sentence': "%(person)s was tagged '%(tag_name)s' by %(actor)s",
        'transformer': {
            'tag_name': linked_person_tag
        }
    },
    'tag_delete': {
        'sentence': "%(actor)s removed tag '%(tag_name)s' from %(person)s",
        'transformer': {
            'tag_name': linked_person_tag
        }
    },
    'watch_add': {
        'sentence': "%(actor)s is now following %(person)s.",
        'transformer': {}
    },
    'watch_delete': {
        'sentence': "%(actor)s has stopped following %(person)s.",
        'transformer': {}
    },
    'default': {
        'sentence': "%(actor)s performed action '%(action)s' on %(person)s",
        'transformer': {}
    }
}

var default_transformers = {
    'event_class': identity,
    'action': action,
    'actor': linked_person,
    'person': linked_person,
    'page': linked_page
}
var default_sentence =
    "%(actor)s did %(action)s to an %(event_class)s object";

var madlib_constructors = {
    'page' : page_madlib_constructors,
    'person': person_madlib_constructors
}


function identity(x) { return x; }
function action(x) { return x.action; }
// The following 2 functions inspired by http://trac.typosphere.org/browser/trunk/public/javascripts/typo.js
function prettyDateDelta(minutes)
{
    minutes = Math.abs(minutes);
    if (minutes < 1) return "less than a minute";
    if (minutes == 1) return "one minute";
    if (minutes < 50) return String(minutes) + " minutes";
    if (minutes < 90) return "about one hour";
    if (minutes < 1080) return String(Math.round(minutes/60)) + " hours";
    if (minutes < 1440) return "one day";
    if (minutes < 2880) return "about one day";
    return String(Math.round(minutes/1440)) + " days";
}

function getAgoString(then)
{
    var nowts = new Date();
    var now = Number(nowts);
    then = Number(then);

    var delta_minutes;
    if ((now-then) < 0) {
        delta_minutes = 0;
    }
    else {
        delta_minutes = Math.floor((now-then) / (60 * 1000));
    }
    return prettyDateDelta(delta_minutes) + " ago";
}

function madlib_render_event(evt) {
    var then = new Date();
    then.setISO8601(evt.at);

    var cons = madlib_constructors[evt.event_class][evt.action];
    if (cons == null) {
        cons = madlib_constructors[evt.event_class]['default'];
        if (cons == null) {
            return '';
        }
    }

    var sentence = cons['sentence'];
    var keywords = ['actor','action','person','page','tag_name','context'];
    for (var i=0, l=keywords.length; i<l; i++) {
        var keyword = keywords[i];

        var transformer = cons.transformer[keyword];
        if (!transformer) {
            transformer = default_transformers[keyword];
        }
        if (!transformer) continue;

        var pre_val = evt[keyword];
        if (!pre_val) continue;
        
        var val = transformer(evt, pre_val);
        sentence = sentence.replace("%("+keyword+")s", val);
    }

    return "<p>" + sentence + 
        " <span class='madlib-ago'>(" + getAgoString(then) + ")</span></p>";
}
;
// BEGIN jquery.timers.js
jQuery.fn.extend({
	everyTime: function(interval, label, fn, times, belay) {
		return this.each(function() {
			jQuery.timer.add(this, interval, label, fn, times, belay);
		});
	},
	oneTime: function(interval, label, fn) {
		return this.each(function() {
			jQuery.timer.add(this, interval, label, fn, 1);
		});
	},
	stopTime: function(label, fn) {
		return this.each(function() {
			jQuery.timer.remove(this, label, fn);
		});
	}
});

jQuery.extend({
	timer: {
		guid: 1,
		global: {},
		regex: /^([0-9]+)\s*(.*s)?$/,
		powers: {
			// Yeah this is major overkill...
			'ms': 1,
			'cs': 10,
			'ds': 100,
			's': 1000,
			'das': 10000,
			'hs': 100000,
			'ks': 1000000
		},
		timeParse: function(value) {
			if (value == undefined || value == null)
				return null;
			var result = this.regex.exec(jQuery.trim(value.toString()));
			if (result[2]) {
				var num = parseInt(result[1], 10);
				var mult = this.powers[result[2]] || 1;
				return num * mult;
			} else {
				return value;
			}
		},
		add: function(element, interval, label, fn, times, belay) {
			var counter = 0;
			
			if (jQuery.isFunction(label)) {
				if (!times) 
					times = fn;
				fn = label;
				label = interval;
			}
			
			interval = jQuery.timer.timeParse(interval);

			if (typeof interval != 'number' || isNaN(interval) || interval <= 0)
				return;

			if (times && times.constructor != Number) {
				belay = !!times;
				times = 0;
			}
			
			times = times || 0;
			belay = belay || false;
			
			if (!element.$timers) 
				element.$timers = {};
			
			if (!element.$timers[label])
				element.$timers[label] = {};
			
			fn.$timerID = fn.$timerID || this.guid++;
			
			var handler = function() {
				if (belay && this.inProgress) 
					return;
				this.inProgress = true;
				if ((++counter > times && times !== 0) || fn.call(element, counter) === false)
					jQuery.timer.remove(element, label, fn);
				this.inProgress = false;
			};
			
			handler.$timerID = fn.$timerID;
			
			if (!element.$timers[label][fn.$timerID]) 
				element.$timers[label][fn.$timerID] = window.setInterval(handler,interval);
			
			if ( !this.global[label] )
				this.global[label] = [];
			this.global[label].push( element );
			
		},
		remove: function(element, label, fn) {
			var timers = element.$timers, ret;
			
			if ( timers ) {
				
				if (!label) {
					for ( label in timers )
						this.remove(element, label, fn);
				} else if ( timers[label] ) {
					if ( fn ) {
						if ( fn.$timerID ) {
							window.clearInterval(timers[label][fn.$timerID]);
							delete timers[label][fn.$timerID];
						}
					} else {
						for ( var fn in timers[label] ) {
							window.clearInterval(timers[label][fn]);
							delete timers[label][fn];
						}
					}
					
					for ( ret in timers[label] ) break;
					if ( !ret ) {
						ret = null;
						delete timers[label];
					}
				}
				
				for ( ret in timers ) break;
				if ( !ret ) 
					element.$timers = null;
			}
		}
	}
});

if (jQuery.browser.msie)
	jQuery(window).one("unload", function() {
		var global = jQuery.timer.global;
		for ( var label in global ) {
			var els = global[label], i = els.length;
			while ( --i )
				jQuery.timer.remove(els[i], label);
		}
	});


;
// BEGIN template/dropdown.tt2
/*
   This JavaScript code was generated by Jemplate, the JavaScript
   Template Toolkit. Any changes made to this file will be lost the next
   time the templates are compiled.

   Copyright 2006-2008 - Ingy döt Net - All rights reserved.
*/

if (typeof(Jemplate) == 'undefined')
    throw('Jemplate.js must be loaded before any Jemplate template files');

Jemplate.templateMap['dropdown.tt2'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<ul id="';
//line 1 "dropdown.tt2"
output += stash.get('id');
output += '-list" class="dropdownOptions">\n    ';
//line 6 "dropdown.tt2"

// FOREACH 
(function() {
    var list = stash.get('options');
    list = new Jemplate.Iterator(list);
    var retval = list.get_first();
    var value = retval[0];
    var done = retval[1];
    var oldloop;
    try { oldloop = stash.get('loop') } finally {}
    stash.set('loop', list);
    try {
        while (! done) {
            stash.data['option'] = value;
output += '\n        <li class="dropdownItem ';
//line 3 "dropdown.tt2"
if (stash.get(['loop', 0, 'last', 0])) {
output += 'last';
}

output += '">\n            <a value="';
//line 4 "dropdown.tt2"

// FILTER
output += (function() {
    var output = '';

output += stash.get(['option', 0, 'value', 0]);

    return context.filter(output, 'html', []);
})();

output += '" href="#">';
//line 4 "dropdown.tt2"

// FILTER
output += (function() {
    var output = '';

output += (stash.get(['option', 0, 'optionTitle', 0]) || stash.get(['option', 0, 'title', 0]));

    return context.filter(output, 'html', []);
})();

output += '</a>\n        </li>\n    ';;
            retval = list.get_next();
            value = retval[0];
            done = retval[1];
        }
    }
    catch(e) {
        throw(context.set_error(e, output));
    }
    stash.set('loop', oldloop);
})();

output += '\n</ul>\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

;
// BEGIN Socialtext-Activities/jquery.dropdown.js
(function($){

Dropdown = function(args, node) {
    $.extend(this, $.extend(true, {}, args));
    this.node = node;
    if (!node) throw new Error("node is a required argument");

    var win = window;
    this.$ = window.$;
    try {
        // call window.parent.$ first to make sure we can access properties
        // of window.parent
        if (window.parent.$) {
            win = window.parent;
            this.$ = window.parent.$;
        }
    }
    catch(e) { }

    this.useParent = win != window;
    if (typeof(win.DD_COUNT) == 'undefined') win.DD_COUNT = 0;
    this.id = 'st-dropdown-' + win.DD_COUNT++;
}

Dropdown.prototype = {
    options: [],
    showCount: 0,
    mobile: /(iPad|iPod|iPhone|Android)/.test(navigator.userAgent),

    isSelected: function(option) {
        return option.value == this.selected || option.id == this.selected;
    },

    render: function() {
        var self = this;

        if (this.fixed) {
            this.valueNode = $('<span class="value"></span>');
            $(this.node).append(this.valueNode)
            $.each(this.options, function(i, option) {
                if (self.isSelected(option)) {
                    self._selectOption(option);
                }
            });
            return;
        }

        this.valueNode = $('<a href="#" class="value"></a>')
            .click(function(){ return false; });
        
        if (this.mobile) {
            this.valueNode = $('<span class="value fakeLink"></span>');
        }

        // Strip out hidden options
        this.options = $.grep(this.options, function(o) { return !o.hidden });

        this.$('body').append(Jemplate.process('dropdown.tt2', this));
        if (this.useParent) {
            $(window).unload(function() {
                self.listNode.remove();
            });
        }

        this.listNode = this.$('#' + this.id + '-list');
        if (!this.listNode.size())
            throw new Error("Can't find ul node");
        if (this.width) this.listNode.css('width', this.width);

        var $arrow = $('<span class="arrow">&#9660;</span>');

        $(this.node).append(this.valueNode).append($arrow);

        if (!self.mobile) {
            $(self.node).mouseover(function() { self.show() });
            $(self.node).mouseout(function() { self.hide() });
            self.listNode.mouseover(function() { self.show() });
            self.listNode.mouseout(function() { self.hide() });
        }

        if ($.browser.msie) {
            $('.options li').mouseover(function() {
                var li = this;
                setTimeout(function() {
                    $(li).addClass('hover');
                }, 0);
            });
            $('.options li').mouseout(function() {
                var li = this;
                setTimeout(function() {
                    $(li).removeClass('hover');
                }, 0);
            });
        }

        var $mobileSelect;
        $.each(this.options, function(i, option) {
            if (self.mobile) {
                if (!$mobileSelect) {
                    $mobileSelect = $('<select></select>')
                        .change(function() { self.selectValue($(this).val()) })
                        .appendTo(self.node);
                }
                $('<option></option>')
                    .attr('value', option.value)
                    .text(option.title)
                    .click(function() { self.selectValue(option.value) })
                    .appendTo($mobileSelect);
            }

            option.node = self.listNode.find('li a').get(i);
            self.$(option.node).click(function() {
                self.selectOption(option);
                return false;
            });
            if (self.isSelected(option)) {
                self._selectOption(option);
            }
        });
    },

    show: function() {
        var offset = this.useParent
            ? this.$('iframe[name='+window.name+']').offset()
            : {top: 0, left: 0};

        offset.left += this.$(this.node).offset().left;

        offset.top  += this.$(this.node).offset().top
                     + this.$(this.node).height()
                     - 1; // Offset to fix {bz: 3654}

        if (this.useParent) {
            // Fix {bz: 4711} when we are in an iframe, but don't trigger {bz: 4782} if we're not 
            offset.top -= (window.top.scrollY || 0);
            offset.left -= (window.top.scrollX || 0);
        }

        this.listNode.css({ 'left': offset.left, 'top': offset.top });

        this.showCount++; // cancel any pending hides
        this.listNode.show();
    },

    hide: function() {
        var self = this;
        // Only hide the listNode if we haven't called show() within 50ms of
        // creating this timeout:
        var cnt = self.showCount;
        setTimeout(function() {
            if (cnt == self.showCount) self.listNode.hide();
        }, 50);
    },

    _selectOption: function(option, callback) {
        if (!this.fixed) {
            if (this.$(option.node).parents('li.disabled.dropdownItem').size())
                return;
            this.listNode.find('li.selected').removeClass('selected');
            this.$(option.node).parents('li.dropdownItem').addClass('selected');

            // Hide the context menu
            this.listNode.hide();
        }

        // Store the selected option
        this._selectedOption = option;

        if (this.valueNode.text() != option.title) {
            // Display the new value and fire onChange if
            // the new value is different
            this.valueNode.text(option.title);

            // mobile
            if (this.mobile) {
                $(this.node).find('select')
                    .width(this.valueNode.width() + 10)
                    .val(option.value);
            }

            if ($.isFunction(callback)) {
                callback();
            }
        }
    },

    selectOption: function(option) {
        var self = this;
        this._selectOption(option, function() {
            if ($.isFunction(self.onChange)) {
                self.onChange(option);
            }
        });
    },

    selectedOption: function() {
        return this._selectedOption;
    },

    selectValue: function(value) {
        var self = this;
        $.each(this.options, function(i, option) {
            if (option.value == value) {
                self.selectOption(option);
            }
        });
    },

    selectId: function(id) {
        var self = this;
        $.each(this.options, function(i, option) {
            if (option.id == id) {
                self.selectOption(option);
            }
        });
    },

    enableAllOptions: function() {
        if (this.listNode)
            this.listNode.find('li.disabled').removeClass('disabled').show();
    },

    disableOption: function(value) {
        var self = this;
        var selected = self.selectedOption();

        // Step back to the first not disabled option
        if (selected) {
            if (selected.value == value) {
                var defaults = $.grep(self.options, function(item) {
                    return item['default']
                });
                if (!defaults.length) throw new Error("No default option!")
                self.selectOption(defaults[0]);
            }
        }

        $.each(self.options, function(i, option) {
            if (option.value == value) {
                $(option.node).parents('li.dropdownItem').addClass('disabled');
                if (self.hideDisabled)
                    $(option.node).parents('li.dropdownItem').hide();
            }
        });
    }
};

$.fn.extend({
    dropdown: function(args) {
        this.each(function() {
            if ($(this).hasClass('dropdown')) return;
            $(this).addClass('dropdown');
            this.dropdown = new Dropdown(args, this);
            this.dropdown.render();
        });
    },

    dropdownClick: function(linkNode) {
        this.each(function() {
            this.dropdown.click(linkNode);
        });
    },

    dropdownSelectValue: function(value) {
        $.each(this, function() {
            this.dropdown.selectValue(value);
        });
    },

    dropdownSelectId: function(value) {
        $.each(this, function() {
            this.dropdown.selectId(value);
        });
    },

    dropdownSelectedOption: function() {
        if (!this.size()) return;
        return this.get(0).dropdown.selectedOption();
    },

    dropdownValue: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.value;
    },

    dropdownId: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.id;
    },

    dropdownLabel: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.title;
    },

    dropdownDisable: function(value) {
        $.each(this, function() {
            this.dropdown.disableOption(value);
        });
    },

    dropdownEnable: function() {
        $.each(this, function() {
            this.dropdown.enableAllOptions();
        });
    }
});
})(jQuery);
;
// BEGIN Socialtext/socialtext-api.js
// BEGIN Socialtext/lib/Socialtext/Base.js
(function($){

if (typeof(Socialtext) == 'undefined') Socialtext = {};
Socialtext.Base = function() {};

Socialtext.Base.errorCallback = function(callback) {
    return function(xhr, textStatus, errorThrown) {
        var error = xhr ? xhr.responseText : errorThrown;
        if (!error) error = 'An unknown error occured';
        if (callback)
            callback({errors: [error]});
        else 
            alert(error);
    };
};

Socialtext.Base.prototype = {
    errorCallback: function(callback) {
        return Socialtext.Base.errorCallback(callback);
    },

    successCallback: function(callback) {
        return function(data) { callback({ data: data }) };
    },

    /**
     * run several operations asynchronously
     *
     * takes an array of jobs, each is required to take a callback parameter
     * and call the callback after the operation is completed
     */
    runAsynch: function(jobs, callback) {
        var errors = [];

        var self = this;
        var runJob = function() {
            var job = jobs.shift();
            if (!job) { // done
                self.errors = errors;
                callback({errors: errors});
                return;
            }
            job(function(res) {
                if (res.errors && res.errors.length) {
                    errors = errors.concat(res.errors);
                }
                runJob();
            });
        };
        runJob();
    }
}

})(jQuery);
;
// BEGIN Socialtext/lib/Socialtext/Account.js
(function($){

Socialtext = Socialtext || {};
Socialtext.Account = function(params) {
    $.extend(this, params);
};

Socialtext.Account.prototype = new Socialtext.Base();

$.extend(Socialtext.Account.prototype, {
    url: function(rest) {
        if (!this.account_name && this.account_name)
            throw new Error(loc("api.account-name-required"));
        if (!rest) rest = '';
        return '/data/accounts/' + (this.account_id || this.account_name) + rest;
    },

    addUser: function(user, callback) {
        var self = this;
        if (!user.user_id) throw new Error(loc("api.user_id-required"));
        $.ajax({
            url: this.url('/users'),
            type: 'post',
            contentType: 'application/json',
            data: $.toJSON({ user_id: user.user_id }),
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    },

    addGroup: function(group, callback) {
        var self = this;
        if (!group.group_id) throw new Error(loc("api.group_id-required"));
        $.ajax({
            url: this.url('/groups'),
            type: 'post',
            contentType: 'application/json',
            data: $.toJSON({ group_id: group.group_id }),
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    },

    removeGroup: function(group, callback) {
        var self = this;
        if (!group.group_id) throw new Error(loc("api.group_id-required"));
        $.ajax({
            url: this.url('/groups/' + group.group_id),
            type: 'delete',
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    },

    updateSignalsPrefs: function(prefs, callback) {
        var self = this;
        self.updatePluginPrefs('signals', prefs, callback);
    },

    // Generic
    updatePluginPrefs: function(plugin, prefs, callback) {
        var self = this;
        $.ajax({
            url: this.url('/plugins/' + plugin + '/preferences'),
            type: 'put',
            contentType: 'application/json',
            data: $.toJSON(prefs),
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    },

    updateMember: function(member, callback) {
        var self = this;
        $.ajax({
            url: this.url('/users'),
            type: 'POST',
            contentType: 'application/json',
            data: $.toJSON(member),
            success: function() { self._call(callback) },
            error: self.errorCallback(callback)
        });
    },

    _call: function(callback, opts) {
        if (typeof(opts) == 'undefined') opts = {};
        if ($.isFunction(callback)) callback(opts);
    }
});

})(jQuery);
;
// BEGIN Socialtext/lib/Socialtext/Group.js
(function($){

Socialtext = Socialtext || {};
Socialtext.Group = function(params) {
    $.extend(this, params);
};

Socialtext.Group.GetDrivers = function(callback) {
    $.getJSON('/data/group_drivers', callback);
};

Socialtext.Group.GetDriverGroups = function(driver_key, callback) {
    var url = '/data/group_drivers/' + driver_key + '/groups';
    $.getJSON(url, callback);
};

Socialtext.Group.prototype = new Socialtext.Base();

$.extend(Socialtext.Group.prototype, {
    url: function(rest) {
        rest = rest || '';
        return '/data/groups/' + this.group_id + rest;
    },

    load: function(callback) {
        var self = this;
        $.ajax({
            url: self.url(),
            type: 'get',
            dataType: 'json',
            success: function(data) {
                $.extend(self, data);
                callback();
            },
            error: self.errorCallback(callback)
        });
    },

    saveInfo: function(callback) {
        var self = this;
        if (!this.name && !this.ldap_dn) {
            throw new Error(loc("api.ldap-dn-or-group-name-required"));
        }

        var data = {};
        $.each(Socialtext.Group.Args.PUT, function(i, arg) {
            if (self[arg]) data[arg] = self[arg];
        });

        $.ajax({
            url: self.url(),
            type: 'PUT',
            contentType: 'application/json',
            data: $.toJSON(data),
            success: function() {
                if (callback) callback({});
            },
            error: this.errorCallback(callback)
        });
    },

    save: function(callback) {
        var self = this;
        if (!self.group_id) {
            throw new Error("Can't save group without group_id");
        }

        var users = {
            users: self.users,
            send_message: self.send_message,
            additional_message: self.additional_message
        };
        var jobs = [
            function(cb) { self.saveInfo(cb) },
            function(cb) { self.addMembers(users, cb) },
            function(cb) { self.addToWorkspaces(self.workspaces, cb) },
            function(cb) { self.updateMembers(self.changedmemberships, cb) },
            function(cb) { self.removeMembers(self.trash, cb) },
            function(cb) {
                self.removeFromWorkspaces(self.trashed_workspaces, cb)
            }
        ];
        $.each(self.new_workspaces || [], function(i, info) {
            info.groups = {group_id: self.group_id};
            info.permission_set = self.workspace_compat_perms();
            jobs.push(function(cb) {
                Socialtext.Workspace.Create(info, cb);
            });
        });

        self.runAsynch(jobs, function() {
            self._call(callback, self);
        });
    },

    workspace_compat_perms: function() {
        return (this.permission_set == 'self-join')
            ? 'self-join' : 'member-only';
    },

    /**
     * addMembers(userList, options, callback)
     *
     * accepts: 
     *   an array of users [{user_id:...},...], or
     *   a hash {
     *      users: [], // users
     *      send_message: true/false,
     *      additional_message: "invite message"
     *   }
     */
    addMembers: function(users, callback) {
        // If an array, then make it into a structure
        if ((Object.prototype.toString.call(users) === '[object Array]') ||   !users) { 
            users = {users: (users || [])};
        };
        if (!users.users.length) return callback({});
        this.postItems(this.url('/users'), users, callback);
    },

    _call: function(callback, opts) {
        if (typeof(opts) == 'undefined') opts = {};
        if ($.isFunction(callback)) callback(opts);
    },

    updateMembers: function(members, callback) {
        if (!members.length) return this._call(callback);
        this.postItems(this.url('/membership'), members, callback);
    },

    addToWorkspaces: function(workspaces, callback) {
        if (!workspaces.length) return this._call(callback);
        this.postItems(this.url('/workspaces'), workspaces, callback);
    },

    removeFromWorkspaces: function(workspaces, callback) {
        var self = this;
        var jobs = [];
        if (!workspaces.length) return this._call(callback);
        $.each(workspaces, function(i, info) {
            jobs.push(function(cb) {
                var workspace = new Socialtext.Workspace({
                    name: info.name
                });
                workspace.removeMembers(
                    [ { group_id: self.group_id } ], cb
                );
            });
        });
        this.runAsynch(jobs, callback);
    },

    removeFromAccounts: function(accounts, callback) {
        var self = this;
        var jobs = [];
        if (!accounts.length) return this._call(callback);
        $.each(accounts, function(i, info) {
            jobs.push(function(cb) {
                var account = new Socialtext.Account({
                    account_name: info.name
                });
                account.removeGroup(self, cb);
            });
        });
        this.runAsynch(jobs, callback);
    },

    removeMembers: function(trash, callback) {
        if (!trash.length) return this._call(callback);
        this.postItems(this.url('/trash'), trash, callback);
    },

    postItems: function(url, list, callback) {
        var self = this;
        $.ajax({
            url: url,
            type: 'POST',
            contentType: 'application/json',
            data: $.toJSON(list),
            success: function() { self._call(callback) },
            error: self.errorCallback(callback)
        });
    },

    hasMember: function(username, callback) {
        var self = this;
        if (!Number(self.group_id)) {
            self._call(callback, false);
        }
        else {
            $.ajax({
                url: this.url('/users/' + username),
                type: 'HEAD',
                success: function() { self._call(callback, true) },
                error:   function() { self._call(callback, false) }
            });
        }
    },

    getAdmins: function(callback) {
        $.getJSON(this.url('?show_admins=1'), function(data) { 
            var result=[];
            result = $.map(data.admins, function(elem, index) {
                return elem.user_id;
            });
            callback(result);
        });
    },

    remove: function(callback) {
        $.ajax({
            url: this.url(),
            type: 'DELETE',
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    }
});

Socialtext.Group.Args = {
    POST: [
        'ldap_dn', 'name', 'account_id', 'description', 'photo_id',
        'workspaces', 'users', 'send_message', 'additional_message',
        'new_workspaces', 'permission_set'
    ],
    PUT: [ 'name', 'account_id', 'description', 'photo_id', 'permission_set' ]
};

Socialtext.Group.Create = function(opts, callback) {
    if (!opts.name && !opts.ldap_dn) {
        throw new Error(loc("api.ldap-dn-or-group-name-required"));
    }

    var data = {};
    $.each(Socialtext.Group.Args.POST, function(i, arg) {
        if (opts[arg]) data[arg] = opts[arg]
    });

    $.ajax({
        url: '/data/groups',
        type: 'POST',
        dataType: 'json',
        contentType: 'application/json',
        data: $.toJSON(data),
        success: function(data) {
            var group = new Socialtext.Group(data);
            if (callback) callback(group);
        },
        error: function(xhr, textStatus, errorThrown) {
            var error = xhr ? xhr.responseText : errorThrown;
            if (callback) callback({ errors: [error] });
        }
    });
};

})(jQuery);
;
// BEGIN Socialtext/lib/Socialtext/UserAccountRole.js
(function($){

Socialtext = Socialtext || {};

Socialtext.UserAccountRole = function(params) {
    $.extend(this, params);
};

Socialtext.UserAccountRole.prototype = new Socialtext.Base();

$.extend(Socialtext.UserAccountRole.prototype, {
    url: function() {
        if (!this.username) throw new Error(loc("api.username-required"));
        if (!this.account_name)
            throw new Error(loc("api.account_name-required"));

        return '/data/accounts/' + this.account_name +
               '/users/' + this.username;
    },

    remove: function(callback) {
        if (!callback) callback = function(r) { if (r.error) alert(r.error) };
        $.ajax({
            url: this.url(),
            type: 'delete',
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    },

    stringify: function() {
        var roles = [];
        if (this.is_primary != undefined) {
            if (this.is_primary) {
                roles.push(loc("api.primary-account"));
            }
            else {
                roles.push(loc("api.member-of-account"));
            }
        }
        if (this.via_workspace) {
            roles.push(loc(
                "api.via-wiki-count=length,map",
                this.via_workspace.length,
                $.map(this.via_workspace, function (w) {
                    var href = "/nlw/control/workspace/" + w.workspace_id;
                    return '<a href="' + href + '">' + w.name + '</a>';
                }).join(", ")
            ));
        }
        if (this.via_group) {
            roles.push(loc(
                "api.via-group-count=length,map",
                this.via_group.length,
                $.map(this.via_group, function (g) {
                    var href = "/nlw/control/group/" + g.group_id;
                    return '<a href="' + href + '">' + g.name + '</a>';
                }).join(", ")
            ));
        }
        return roles.join(', ');
    }
});

})(jQuery);
;
// BEGIN Socialtext/lib/Socialtext/User.js
(function($){

Socialtext = Socialtext || {};

Socialtext.User = function(params) {
    $.extend(this, params);
};

Socialtext.User.prototype = new Socialtext.Base();

$.extend(Socialtext.User.prototype, {
    create: function() {
        throw new Error(loc("api.unimplemented"));
    },

    url: function() {
        if (!this.user_id) throw new Error(loc("api.no-user-id"));
        return '/data/users/' + this.user_id;
    },

    setPrimaryAccountId: function(id, callback) {
        var self = this;
        if (!callback) callback = function(r) { if (r.error) alert(r.error) };
        if (!id) throw new Error(loc("api.id-required"));
        $.ajax({
            url: this.url(),
            type: 'put',
            contentType: 'application/json',
            data: $.toJSON({
                primary_account_id: id
            }),
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    },

    addToGroups: function(groups, callback) {
        var self = this;
        var jobs = [];
        if (!groups.length) return this.call(callback);
        var errors = [];
        $.each(groups, function(i, info) {
            jobs.push(function(cb) {
                var group = new Socialtext.Group({group_id: info.id});
                group.addMembers(
                    [{user_id: self.user_id, role: 'member'}], cb);
            });
        });
        this.runAsynch(jobs, callback);
    },

    removeFromWorkspaces: function(workspaces, callback) {
        var self = this;
        var jobs = [];
        if (!workspaces.length) return this.call(callback);
        var errors = [];
        $.each(workspaces, function(i, info) {
            jobs.push(function(cb) {
                var workspace = new Socialtext.Workspace({
                    name: info.name
                });
                workspace.removeMembers([ { user_id: self.user_id } ], cb);
            });
        });
        this.runAsynch(jobs, callback);
    }
});

})(jQuery);
;
// BEGIN Socialtext/lib/Socialtext/Workspace.js
(function($) {

Socialtext = Socialtext || {};
Socialtext.Workspace = function(params) {
    delete params.create;
    $.extend(this, params);
};

Socialtext.Workspace.prototype = new Socialtext.Base();

$.extend(Socialtext.Workspace.prototype, {
    url: function(extra) {
        if (!extra) extra = '';
        return '/data/workspaces/' + this.name + extra
    },
    load: function(callback) {
        var self = this;
        $.ajax({
            url: self.url(),
            type: 'get',
            dataType: 'json',
            success: function(data) {
                $.extend(self, data);
                callback();
            },
            error: self.errorCallback(callback)
        });
    },
    _splitMemberRoles: function(members) {
        // XXX: We should make /data/workspace/:ws/members so we don't need to
        // split this here
        var roles = { users: [], groups: [] };
        $.each(members, function(i, mem) {
            var role = {};
            if (mem.role_name) role.role_name = mem.role_name;
            if (mem.group_id) role.group_id = mem.group_id;
            if (mem.user_id) role.user_id = mem.user_id;
            if (mem.username) role.username = mem.username;
            if (mem.group_id) {
                roles.groups.push(role);
            }
            else if (mem.user_id || mem.username) {
                roles.users.push(role);
            }
        });
        return roles;
    },
    _hasImpersonators: function(members) {
        var self = this;

        var hasImpersonators = false;
        $(members).each(function(i, member) {
            if (member.roles && $.inArray('impersonator', member.roles) != -1) {
                hasImpersonators = true;
            }
        });

        return hasImpersonators;
    },
    _request: function(method, collection, data, callback) {
        var self = this;
        $.ajax({
            url: self.url('/' + collection),
            type: method,
            contentType: 'application/json',
            data: $.toJSON(data),
            success: self.successCallback(callback),
            error: self.errorCallback(callback)
        });
    },
    updateMembers: function(members, callback) {
        var self = this;
        if (self._hasImpersonators(members)) {
            callback({errors: [loc('api.impersonators-can-only-be-managed-by-admins')]});
        }
        else {
            var types = self._splitMemberRoles(members);
            if (!types.users.length && !types.groups.length) {
                throw new Error(loc("api.no-members-specified"));
            }
            var jobs = [];
            if (types.users.length) {
                jobs.push(function(cb) {
                    self._request('PUT', 'users', types.users, cb)
                });
            }
            if (types.groups.length) {
                jobs.push(function(cb) {
                    self._request('PUT', 'groups', types.groups, cb)
                });
            }
            self.runAsynch(jobs, callback);
        }
    },
    addMembers: function(members, callback) {
        var self = this;
        var jobs = [];
        $.each(members, function(i, member) {
            if (member.group_id) {
                jobs.push(function(cb) {
                    self._request('POST', 'groups', member, cb)
                });
            }
            else {
                jobs.push(function(cb) {
                    self._request('POST', 'users', member, cb)
                });
            }
        });
        this.runAsynch(jobs, callback);
    },
    removeMembers: function(members, callback) {
        var self = this;

        if (self._hasImpersonators(members)) {
            callback({errors: ['Impersonators can only be managed by system administrators']});
        }
        else {
            var data = $.map(members, function(member) {
                var r = {};
                if (member.user_id) r.user_id = member.user_id;
                if (member.group_id) r.group_id = member.group_id;
                if (member.username) r.username = member.username;
                return r;
            });
            $.ajax({
                url: this.url('/trash'),
                type: 'POST',
                contentType: 'application/json',
                data: $.toJSON(data),
                success: this.successCallback(callback),
                error: this.errorCallback(callback)
            });
        }
    }
});

/**
 * Class Methods
 */
Socialtext.Workspace.All = function(callback) {
    $.ajax({
        url: '/data/workspaces',
        type: 'get',
        dataType: 'json',
        success: function(data) {
            var workspaces = [];
            $.each(data, function(i, w) {
                workspaces.push( new Socialtext.Workspace(w) );
            });
            callback({ data: workspaces });
        },
        error: function(xhr, textStatus, errorThrown) {
            var error = xhr ? xhr.responseText : errorThrown;
            callback({ error: error });
        }
    });
};

Socialtext.Workspace.Create = function(opts, callback) {
    try {
        if (!opts.title) throw new Error(loc("api.title-required"));
        if (!opts.name) throw new Error(loc("api.name-required"));
        Socialtext.Workspace.AssertValidTitle(opts.title);
        Socialtext.Workspace.AssertValidName(opts.name);
    }
    catch(e) {
        callback({error: e.message});
        return;
    }

    var data = {};
    if (opts.title) data.title = opts.title;
    if (opts.name) data.name = opts.name;
    if (opts.groups) data.groups = opts.groups;
    if (opts.account_id) data.account_id = opts.account_id;
    if (opts.members) data.members = opts.members;
    if (opts.permission_set) data.permission_set = opts.permission_set;

    opts.accept = 'application/json';

    $.ajax({
        url: '/data/workspaces',
        type: 'POST',
        contentType: 'application/json',
        data: $.toJSON(data),
        success: function(data) {
            var workspace = new Socialtext.Workspace({name: opts.name});
            if (callback) callback(workspace);
        },
        error: function(xhr, textStatus, errorThrown) {
            var error = xhr ? xhr.responseText : errorThrown;
            if (callback) callback({ error: error || textStatus });
        }
    });
}

Socialtext.Workspace.ReservedNames = [
    'account', 'administrate', 'administrator', 'atom', 'attachment',
    'attachments', 'category', 'control', 'console', 'data', 'feed', 'nlw',
    'noauth', 'page', 'recent-changes', 'rss', 'search', 'soap', 'static',
    'st-archive', 'superuser', 'test-selenium', 'workspace', 'user'
];

Socialtext.Workspace.AssertValidTitle = function (title) {
    if (title.match(/^-/)) {
        throw new Error(loc('api.wiki-title-cannot-begin-with-dash'));
    }
    if (title.length < 2 || title.length > 64) {
        throw new Error(loc("api.about-wiki-title"));
    }
};

Socialtext.Workspace.AssertValidName = function (name) {
    var reserved = Socialtext.Workspace.ReservedNames;
    if ($.inArray(name, reserved) >= 0 || name.match(/^st_/)) {
        throw new Error(loc("api.is-reserved-word=name", name));
    }
    if (name.match(/^-/)) {
        throw new Error(loc('api.wiki-name-cannot-begin-with-dash'));
    }
    if (!name.match(/^[a-z0-9_-]{3,30}$/)) {
        throw new Error(
            loc('api.about-wiki-name')
        );
    }
};


/* DO NOT EDIT THIS FUNCTION! run dev-bin/generate-title-to-id-js.pl --dash instead */
/* DO NOTE THAT FOR WORKSPACES WE USE DASH (-) INSTEAD OF UNDERSCORE (_) */
Socialtext.Workspace.page_title_to_page_id = function (str) {
    str = str.replace(/^\s+/, '').replace(/\s+$/, '').replace(/[\u0000-\u002F\u003A-\u0040\u005B-\u005E\u0060\u007B-\u00A9\u00AB-\u00B1\u00B4\u00B6-\u00B8\u00BB\u00BF\u00D7\u00F7\u02C2-\u02C5\u02D2-\u02DF\u02E5-\u02EB\u02ED\u02EF-\u02FF\u0375\u0378-\u0379\u037E-\u0385\u0387\u038B\u038D\u03A2\u03F6\u0482\u0526-\u0530\u0557-\u0558\u055A-\u0560\u0588-\u0590\u05BE\u05C0\u05C3\u05C6\u05C8-\u05CF\u05EB-\u05EF\u05F3-\u060F\u061B-\u0620\u065F\u066A-\u066D\u06D4\u06DD\u06E9\u06FD-\u06FE\u0700-\u070F\u074B-\u074C\u07B2-\u07BF\u07F6-\u07F9\u07FB-\u07FF\u082E-\u08FF\u093A-\u093B\u094F\u0956-\u0957\u0964-\u0965\u0970\u0973-\u0978\u0980\u0984\u098D-\u098E\u0991-\u0992\u09A9\u09B1\u09B3-\u09B5\u09BA-\u09BB\u09C5-\u09C6\u09C9-\u09CA\u09CF-\u09D6\u09D8-\u09DB\u09DE\u09E4-\u09E5\u09F2-\u09F3\u09FA-\u0A00\u0A04\u0A0B-\u0A0E\u0A11-\u0A12\u0A29\u0A31\u0A34\u0A37\u0A3A-\u0A3B\u0A3D\u0A43-\u0A46\u0A49-\u0A4A\u0A4E-\u0A50\u0A52-\u0A58\u0A5D\u0A5F-\u0A65\u0A76-\u0A80\u0A84\u0A8E\u0A92\u0AA9\u0AB1\u0AB4\u0ABA-\u0ABB\u0AC6\u0ACA\u0ACE-\u0ACF\u0AD1-\u0ADF\u0AE4-\u0AE5\u0AF0-\u0B00\u0B04\u0B0D-\u0B0E\u0B11-\u0B12\u0B29\u0B31\u0B34\u0B3A-\u0B3B\u0B45-\u0B46\u0B49-\u0B4A\u0B4E-\u0B55\u0B58-\u0B5B\u0B5E\u0B64-\u0B65\u0B70\u0B72-\u0B81\u0B84\u0B8B-\u0B8D\u0B91\u0B96-\u0B98\u0B9B\u0B9D\u0BA0-\u0BA2\u0BA5-\u0BA7\u0BAB-\u0BAD\u0BBA-\u0BBD\u0BC3-\u0BC5\u0BC9\u0BCE-\u0BCF\u0BD1-\u0BD6\u0BD8-\u0BE5\u0BF3-\u0C00\u0C04\u0C0D\u0C11\u0C29\u0C34\u0C3A-\u0C3C\u0C45\u0C49\u0C4E-\u0C54\u0C57\u0C5A-\u0C5F\u0C64-\u0C65\u0C70-\u0C77\u0C7F-\u0C81\u0C84\u0C8D\u0C91\u0CA9\u0CB4\u0CBA-\u0CBB\u0CC5\u0CC9\u0CCE-\u0CD4\u0CD7-\u0CDD\u0CDF\u0CE4-\u0CE5\u0CF0-\u0D01\u0D04\u0D0D\u0D11\u0D29\u0D3A-\u0D3C\u0D45\u0D49\u0D4E-\u0D56\u0D58-\u0D5F\u0D64-\u0D65\u0D76-\u0D79\u0D80-\u0D81\u0D84\u0D97-\u0D99\u0DB2\u0DBC\u0DBE-\u0DBF\u0DC7-\u0DC9\u0DCB-\u0DCE\u0DD5\u0DD7\u0DE0-\u0DF1\u0DF4-\u0E00\u0E3B-\u0E3F\u0E4F\u0E5A-\u0E80\u0E83\u0E85-\u0E86\u0E89\u0E8B-\u0E8C\u0E8E-\u0E93\u0E98\u0EA0\u0EA4\u0EA6\u0EA8-\u0EA9\u0EAC\u0EBA\u0EBE-\u0EBF\u0EC5\u0EC7\u0ECE-\u0ECF\u0EDA-\u0EDB\u0EDE-\u0EFF\u0F01-\u0F17\u0F1A-\u0F1F\u0F34\u0F36\u0F38\u0F3A-\u0F3D\u0F48\u0F6D-\u0F70\u0F85\u0F8C-\u0F8F\u0F98\u0FBD-\u0FC5\u0FC7-\u0FFF\u104A-\u104F\u109E-\u109F\u10C6-\u10CF\u10FB\u10FD-\u10FF\u1249\u124E-\u124F\u1257\u1259\u125E-\u125F\u1289\u128E-\u128F\u12B1\u12B6-\u12B7\u12BF\u12C1\u12C6-\u12C7\u12D7\u1311\u1316-\u1317\u135B-\u135E\u1360-\u1368\u137D-\u137F\u1390-\u139F\u13F5-\u1400\u166D-\u166E\u1680\u169B-\u169F\u16EB-\u16ED\u16F1-\u16FF\u170D\u1715-\u171F\u1735-\u173F\u1754-\u175F\u176D\u1771\u1774-\u177F\u17B4-\u17B5\u17D4-\u17D6\u17D8-\u17DB\u17DE-\u17DF\u17EA-\u17EF\u17FA-\u180A\u180E-\u180F\u181A-\u181F\u1878-\u187F\u18AB-\u18AF\u18F6-\u18FF\u191D-\u191F\u192C-\u192F\u193C-\u1945\u196E-\u196F\u1975-\u197F\u19AC-\u19AF\u19CA-\u19CF\u19DB-\u19FF\u1A1C-\u1A1F\u1A5F\u1A7D-\u1A7E\u1A8A-\u1A8F\u1A9A-\u1AA6\u1AA8-\u1AFF\u1B4C-\u1B4F\u1B5A-\u1B6A\u1B74-\u1B7F\u1BAB-\u1BAD\u1BBA-\u1BFF\u1C38-\u1C3F\u1C4A-\u1C4C\u1C7E-\u1CCF\u1CD3\u1CF3-\u1CFF\u1DE7-\u1DFC\u1F16-\u1F17\u1F1E-\u1F1F\u1F46-\u1F47\u1F4E-\u1F4F\u1F58\u1F5A\u1F5C\u1F5E\u1F7E-\u1F7F\u1FB5\u1FBD\u1FBF-\u1FC1\u1FC5\u1FCD-\u1FCF\u1FD4-\u1FD5\u1FDC-\u1FDF\u1FED-\u1FF1\u1FF5\u1FFD-\u203E\u2041-\u2053\u2055-\u206F\u2072-\u2073\u207A-\u207E\u208A-\u208F\u2095-\u20CF\u20F1-\u2101\u2103-\u2106\u2108-\u2109\u2114\u2116-\u2118\u211E-\u2123\u2125\u2127\u2129\u212E\u213A-\u213B\u2140-\u2144\u214A-\u214D\u214F\u218A-\u245F\u249C-\u24E9\u2500-\u2775\u2794-\u2BFF\u2C2F\u2C5F\u2CE5-\u2CEA\u2CF2-\u2CFC\u2CFE-\u2CFF\u2D26-\u2D2F\u2D66-\u2D6E\u2D70-\u2D7F\u2D97-\u2D9F\u2DA7\u2DAF\u2DB7\u2DBF\u2DC7\u2DCF\u2DD7\u2DDF\u2E00-\u2E2E\u2E30-\u3004\u3008-\u3020\u3030\u3036-\u3037\u303D-\u3040\u3097-\u3098\u309B-\u309C\u30A0\u30FB\u3100-\u3104\u312E-\u3130\u318F-\u3191\u3196-\u319F\u31B8-\u31EF\u3200-\u321F\u322A-\u3250\u3260-\u327F\u328A-\u32B0\u32C0-\u33FF\u4DB6-\u4DFF\u9FCC-\u9FFF\uA48D-\uA4CF\uA4FE-\uA4FF\uA60D-\uA60F\uA62C-\uA63F\uA660-\uA661\uA673-\uA67B\uA67E\uA698-\uA69F\uA6F2-\uA716\uA720-\uA721\uA789-\uA78A\uA78D-\uA7FA\uA828-\uA82F\uA836-\uA83F\uA874-\uA87F\uA8C5-\uA8CF\uA8DA-\uA8DF\uA8F8-\uA8FA\uA8FC-\uA8FF\uA92E-\uA92F\uA954-\uA95F\uA97D-\uA97F\uA9C1-\uA9CE\uA9DA-\uA9FF\uAA37-\uAA3F\uAA4E-\uAA4F\uAA5A-\uAA5F\uAA77-\uAA79\uAA7C-\uAA7F\uAAC3-\uAADA\uAADE-\uABBF\uABEB\uABEE-\uABEF\uABFA-\uABFF\uD7A4-\uD7AF\uD7C7-\uD7CA\uD7FC-\uF8FF\uFA2E-\uFA2F\uFA6E-\uFA6F\uFADA-\uFAFF\uFB07-\uFB12\uFB18-\uFB1C\uFB29\uFB37\uFB3D\uFB3F\uFB42\uFB45\uFBB2-\uFBD2\uFD3E-\uFD4F\uFD90-\uFD91\uFDC8-\uFDEF\uFDFC-\uFDFF\uFE10-\uFE1F\uFE27-\uFE32\uFE35-\uFE4C\uFE50-\uFE6F\uFE75\uFEFD-\uFF0F\uFF1A-\uFF20\uFF3B-\uFF3E\uFF40\uFF5B-\uFF65\uFFBF-\uFFC1\uFFC8-\uFFC9\uFFD0-\uFFD1\uFFD8-\uFFD9\uFFDD-\uFFFF]+/g,'-');
    str = str.replace(/-+/g, '-');
    str = str.replace(/(^-|-$)/g, '');
    if (str == '0') str = '-';
    if (str == '') str = '-';
    return str.toLocaleLowerCase();
} /* function page_title_to_page_id */

Socialtext.Workspace.TitleToName = function (title) {
    if (title == '')
        return '';
    return encodeURI(this.page_title_to_page_id(title));
};

Socialtext.Workspace.CheckExists = function (name, callback) {
    $.ajax({
        url: '/data/workspaces/' + name,
        type: 'get',
        dataType: 'json',
        complete: function(xhr) {
            if (xhr.status == 200) {
                callback(true);
            }
            else if (xhr.status == 404) {
                callback(false);
            }
            else {
                throw new Error(loc("api.error-checking-for-wiki-existence"));
            }
        }
    });
};

})(jQuery);
;
;
