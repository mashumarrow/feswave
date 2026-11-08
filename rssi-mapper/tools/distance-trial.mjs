// Run with the mapper open in Android Chrome. Samples go to stdout as JSONL.
import { execFileSync } from 'node:child_process';
import { once } from 'node:events';
import { setTimeout as delay } from 'node:timers/promises';

function installTrial() {
  if (window.rssiDistanceTrial) return;
  if (typeof updateMeasurement !== 'function') throw Error('測定ページを再読み込みしてください');
  const points = Array.from({length:11}, (_, i) => i / 2);
  const stops = [...points, ...points.slice().reverse()];
  const panel = document.createElement('section');
  panel.innerHTML = '<b></b><p></p><button>到着・測定開始</button>';
  document.querySelector('h1').after(panel);
  panel.scrollIntoView();
  const title = panel.querySelector('b'), status = panel.querySelector('p');
  const button = panel.querySelector('button');
  const state = window.rssiDistanceTrial = {rows:[], done:false};
  let index=0, start=null, valid=0;
  function next() {
    title.textContent = index===stops.length ? '往復測定完了' :
      (index<11?'往路':'復路')+' · 左から '+stops[index].toFixed(1)+' m';
    button.disabled=index===stops.length;
    state.done=button.disabled;
  }
  button.onclick=()=>{
    start=performance.now();valid=0;button.disabled=true;status.textContent='その場で6秒静止';
  };
  const original=updateMeasurement;
  updateMeasurement=function(data) {
    original(data);
    if(start===null)return;
    const elapsed=performance.now()-start;
    if(elapsed>=1000 && elapsed<=6000) {
      state.rows.push({time:Date.now(),pass:index<11?'out':'back',m:stops[index],
        left:data.left??null,right:data.right??null,online:data.online===true});
      if(data.online && Number.isFinite(data.left) && Number.isFinite(data.right))valid++;
    }
    if(elapsed<6000)return;
    start=null;button.disabled=false;
    if(valid<5) {
      state.rows=state.rows.filter(r=>!(r.m===stops[index] && r.pass===(index<11?'out':'back')));
      status.textContent='受信不足です。同じ地点でもう一度押してください';return;
    }
    index++;next();
    status.textContent=state.done?'記録しました':index===11?'一歩離れて同じ右端に戻り、復路を開始':'記録しました。次の地点へ移動';
  };
  next();
}

const adb=(...args)=>execFileSync('adb',args,{encoding:'utf8'}).trim();
const port=adb('forward','tcp:0','localabstract:chrome_devtools_remote');
process.on('exit',()=>{try{adb('forward','--remove','tcp:'+port)}catch{}});
process.on('SIGINT',()=>process.exit(0));
process.on('SIGTERM',()=>process.exit(0));
const tabs=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();
const tab=tabs.find(t=>t.url==='http://192.168.4.1/');
if(!tab)throw Error('Chromeで測定ページを開いてください');
const ws=new WebSocket(tab.webSocketDebuggerUrl);await once(ws,'open');
let id=0;
async function evaluate(expression){
  const reply=once(ws,'message',{signal:AbortSignal.timeout(5000)});
  ws.send(JSON.stringify({id:++id,method:'Runtime.evaluate',params:{expression,returnByValue:true}}));
  const response=JSON.parse((await reply)[0].data);
  if(response.error||response.result?.exceptionDetails)throw Error(JSON.stringify(response));
  return response.result.result.value;
}
await evaluate('('+installTrial.toString()+')()');
let count=0;
for(;;){
  // Emit completed stops only, so a retry never duplicates a partial stop.
  const state=await evaluate('(()=>{const s=window.rssiDistanceTrial;if(!s)throw Error("page reloaded");return {rows:s.rows.slice('+count+'),done:s.done,ready:!document.querySelector("h1 + section button").disabled}})()');
  if(state.ready||state.done){
    for(const row of state.rows)console.log(JSON.stringify(row));
    count+=state.rows.length;
  }
  if(state.done)break;
  await delay(250);
}
ws.close();
