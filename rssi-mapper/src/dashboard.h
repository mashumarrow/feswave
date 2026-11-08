#pragma once
static const char dashboard[] PROGMEM = R"HTML(<!doctype html><html lang="ja"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>RSSI 測位テスト</title><style>
*{box-sizing:border-box}body{margin:0;background:#f4f4ed;color:#142d2c;font:16px/1.6 system-ui,sans-serif}
main{max-width:620px;margin:6vh auto;padding:22px}h1{font-size:clamp(28px,6vw,42px);letter-spacing:-.05em}
section{background:white;border:1px solid #cdd4ce;padding:22px;border-radius:12px;margin:18px 0}
.row{display:flex;justify-content:space-between;gap:10px}output{font:600 23px monospace}
.track{height:20px;background:linear-gradient(90deg,#b7ded9 33%,#dde2d7 33% 67%,#f6d2a5 67%);position:relative;margin:20px 0;border-radius:12px}
#marker{position:absolute;top:50%;transform:translate(-50%,-50%);width:22px;height:22px;border-radius:50%;background:#173f3c;border:3px solid white;box-shadow:0 0 0 2px #173f3c}
button{background:#174641;color:white;border:0;border-radius:7px;padding:12px;font:inherit}button:disabled{opacity:.45}
small{display:block;margin:10px 0;color:#405951}</style><main><h1>RSSI 測位テスト</h1>
<p id="status" role="status">受信機に接続中…</p><section><div class="row"><b>左の受信機</b><b>右の受信機</b></div>
<div class="row"><output id="left">—</output><output id="right">—</output></div>
<div class="track"><span id="marker" hidden></span></div><strong id="zone">測定待ち</strong>
<small>このスマホの信号を比較しています。目盛りは左右の傾向を示します。</small></section>
<button id="cal" disabled>ここを中央として補正</button> <button id="reset" hidden>補正を解除</button>
<small id="offset"></small><section><h2>位置を記録</h2>
<p>実際に立っている位置を押し、12秒間その場でスマホを持ってください。</p>
<button data-place="L">左</button> <button data-place="C">中央</button> <button data-place="R">右</button>
<small id="trial" role="status">記録待ち</small></section></main><script>
const el=id=>document.getElementById(id);
let bias=0, delta=null;
function showBias(){
  el('offset').textContent='中央の補正値 '+bias.toFixed(1)+' dB（このページのみ）';
  el('reset').hidden=bias===0;
}
function render(data){
  const {left,right,online}=data;
  for(const [id,value] of Object.entries({left,right}))
    el(id).textContent=Number.isFinite(value)?value.toFixed(1)+' dBm':'—';
  delta=online && Number.isFinite(left) && Number.isFinite(right)?right-left:null;
  el('cal').disabled=delta===null;
  el('marker').hidden=delta===null;
  el('status').textContent=online?'右受信機 接続中':'右受信機の通信待ち';
  if(delta===null){el('zone').textContent='測定待ち';return}
  const d=delta-bias;
  const zone=d < -4 ? 0 : d > 4 ? 2 : 1;
  el('marker').style.left=[16.7,50,83.3][zone]+'%';
  el('zone').textContent=['左寄り','左右同程度','右寄り'][zone]+'  ·  補正後の差 '+d.toFixed(1)+' dB';
}
let latest={};
el('cal').onclick=()=>{if(delta!==null){bias=delta;showBias();render(latest)}};
el('reset').onclick=()=>{bias=0;showBias();render(latest)};
const session=crypto.getRandomValues(new Uint32Array(1))[0].toString(16);
let place='', trial=0, until=0, received=0;
const placeButtons=[...document.querySelectorAll('[data-place]')];
function setTrialControls(active){for(const b of placeButtons)b.disabled=active}
for(const b of placeButtons)b.onclick=()=>{
  place=b.dataset.place;trial++;received=0;until=performance.now()+12000;
  setTrialControls(true);el('trial').textContent=b.textContent+'で記録中…';
};
async function poll(){
  if(place && performance.now()>=until){
    place='';setTrialControls(false);
    el('trial').textContent='記録終了 · 左右がそろった回数 '+received+' 回';
  }
  const label=place;
  const params=new URLSearchParams();
  if(label){params.set('place',label);params.set('session',session);params.set('trial',trial);params.set('bias',bias.toFixed(2))}

  try{
    const response=await fetch('/api/me'+(label?'?'+params:''),{cache:'no-store',signal:AbortSignal.timeout(3000)});
    if(!response.ok)throw Error();
    latest=await response.json();render(latest);
    if(label && delta!==null)received++;
  }catch{latest={};render(latest);el('status').textContent='左受信機と通信できません。Wi-Fi接続を確認してください。'}
  setTimeout(poll,500);
}
showBias();poll();</script></html>)HTML";
