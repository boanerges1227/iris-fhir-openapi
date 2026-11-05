'use strict';
const $ = id => document.getElementById(id);
let csrf = '', snapshot = '', capability = null, preview = null, exported = null, report = null, busy = false, revision = 0;
const codes = ['read','vread','create','update','patch','delete','search-type','history-instance','history-type','search-system','history-system','batch','transaction'];

// Create controlled DOM; never execute metadata names or descriptions as HTML.
function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}

// All API calls use same-origin sessions and CSRF; passwords are never saved in local storage.
async function api(path, body) {
  const response = await fetch(`./api/v1/${path}`, {method: body ? 'POST' : 'GET', credentials: 'same-origin', headers: {'Content-Type':'application/json','X-CSRF-Token':csrf}, body: body ? JSON.stringify(body) : undefined});
  if(response.status===401){location.assign(location.pathname.replace(/\/$/,'')+'_login/index.html');throw new Error('Please log in again.');}
  let value;
  try { value = await response.json(); } catch { throw new Error(`Service response could not be parsed (HTTP ${response.status}); check login and app configuration.`); }
  if (!response.ok) {
    const error = new Error(value.error || `Request failed (HTTP ${response.status})`);
    error.result = value;
    throw error;
  }
  return value;
}

// Invalidate the old snapshot immediately after source changes; prevent downloading results from a previous source.
function invalidate() {
  revision++;
  snapshot = ''; preview = null; exported = null; report = null;
  $('resources').replaceChildren(element('div','Waiting for service capability snapshot','empty'));
  $('summary').textContent = 'Resources and interactions shown after reading capabilities.';
  $('spec-preview').value = '';
  refreshButtons();
}

// Downloadable state only comes from successful responses; error reports never unlock spec download.
function refreshButtons() {
  document.querySelectorAll('main input, main select, main textarea, main button').forEach(node => node.disabled = busy);
  $('inspect').disabled = busy;
  $('generate').disabled = busy || !snapshot;
  $('download-spec').disabled = busy || !exported;
  $('download-report').disabled = busy || !report;
}

// Clear old products when export options change; keep the preview for the same source so the user can continue choosing.
function clearExport() {
  exported=null;report=null;$('spec-preview').value='';
  $('diagnostics').replaceChildren(element('p','Configuration changed; please regenerate.','hint'));
  refreshButtons();
}

// Re-collect source auth on every request; clear input fields after the request completes.
function source() {
  const kind = $('source-kind').value;
  if (kind === 'local') return {kind, endpoint:$('endpoint').value};
  if (kind === 'file') {
    if (!capability) throw new Error('Please select a CapabilityStatement JSON file first.');
    return {kind, capability};
  }
  const auth = {kind:$('source-auth').value};
  if (auth.kind === 'bearer') auth.token = $('source-secret').value;
  if (auth.kind === 'basic') Object.assign(auth,{username:$('source-user').value,password:$('source-secret').value});
  return {kind, baseUrl:$('source-url').value, auth};
}

// Export security definitions are separate from collection auth; the public spec never contains source credentials.
function options() {
  const security = {mode:$('public-security').value};
  if (security.mode === 'apiKey') Object.assign(security,{name:$('api-key-name').value,in:$('api-key-in').value});
  if (security.mode === 'oauth2') security.flows = JSON.parse($('oauth-flows').value);
  return {source:source(), publicBaseUrl:$('public-url').value,info:{title:$('api-title').value,version:$('api-version').value},resources:{include:[...document.querySelectorAll('#resources input:checked')].map(x=>x.value)},interactions:{include:[...document.querySelectorAll('#interactions input:checked')].map(x=>x.value)},searchMethods:[...($('search-get').checked?['GET']:[]),...($('search-post').checked?['POST']:[])],includeMetadata:$('include-metadata').checked,includeConditionalInteractions:$('conditional').checked,failurePolicy:$('strict').checked?'strict':'report',security};
}

// Display declared capabilities, all selected by default; resource search only affects display, not selections.
function showPreview(value) {
  const nodes = value.resources.slice().sort((a,b)=>a.type.localeCompare(b.type)).map(r=>{
    const label=element('label',undefined,'resource'),check=element('input');
    check.type='checkbox';check.checked=true;check.value=r.type;
    label.append(check,element('span',r.type),element('small',`${Object.keys(r.interactions).length} interactions · ${r.searchParameterCount} params`));
    return label;
  });
  $('resources').replaceChildren(...nodes);
  $('summary').textContent=`FHIR ${value.fhirVersion} · ${nodes.length} resources · ${value.report.source.visibility}`;
}

// Present diagnostics as plain text, preserving stable codes for delivery to gateway teams.
function showReport(value) {
  report=value;
  const nodes=(value?.diagnostics||[]).map(d=>{
    const card=element('div',undefined,`diagnostic ${d.severity}`);
    card.append(element('strong',`${d.severity.toUpperCase()} · ${d.code}`),element('p',d.message));
    if(d.resourceType||d.sourcePointer) card.append(element('small',`${d.resourceType||''} ${d.sourcePointer||''}`));
    return card;
  });
  $('diagnostics').replaceChildren(...nodes);
}

// Preview and generation share error paths; any failure clears the last spec.
async function perform(generate) {
  const activeRevision=revision;
  busy=true;exported=null;refreshButtons();$('status').textContent=generate?'Generating spec...':'Reading capabilities...';
  try {
    if (generate) {
      const request=options();request.expectedSourceHash=snapshot;
      const value=await api('generate',request);
      if(activeRevision!==revision)return;
      exported=value.openapi;showReport(value.report);
      $('spec-preview').value=JSON.stringify(exported,null,2);
      $('status').textContent=`Generation complete: ${value.report.counts.generatedOperations} HTTP operations; check diagnostics before downloading.`;
    } else {
      const value=await api('inspect',{source:source()});
      if(activeRevision!==revision)return;
      snapshot=value.sourceHash;preview=value;showPreview(value);showReport(value.report);
      $('status').textContent='Snapshot read; you may now choose the public scope.';
    }
  } catch(error) {
    if(activeRevision!==revision)return;
    $('status').textContent=error.message;
    if(error.result?.report)showReport(error.result.report);
    if(error.result?.httpStatus===409)snapshot='';
  } finally {
    $('source-secret').value='';busy=false;refreshButtons();
  }
}

// Browser generates the file; no server export directory or historical data retained.
function download(value, name) {
  const blob=new Blob([JSON.stringify(value)],{type:'application/json;charset=utf-8'});
  if(name==='openapi.json' && blob.size>26214400){$('status').textContent='Download exceeds 25 MiB; blocked.';return;}
  const url=URL.createObjectURL(blob);
  const anchor=document.createElement('a');anchor.href=url;anchor.download=name;anchor.click();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
}

// Initialize offline controls and fetch current authenticated session state.
async function init() {
  for(const code of codes){const label=element('label',undefined,'check'),check=element('input');check.type='checkbox';check.value=code;check.checked=true;label.append(check,element('span',code));$('interactions').append(label);}
  $('source-kind').onchange=()=>{document.querySelectorAll('[data-source]').forEach(n=>n.hidden=n.dataset.source!==$('source-kind').value);$('include-metadata').checked=$('source-kind').value!=='file';invalidate();};
  for(const id of ['endpoint','source-url','source-auth'])$(id).addEventListener('input',invalidate);
  $('capability-file').onchange=async()=>{invalidate();const fileRevision=revision;capability=null;const file=$('capability-file').files[0];if(!file)return;if(file.size>10485760){$('status').textContent='Metadata file exceeds 10 MiB.';return;}try{const parsed=JSON.parse(await file.text());if(fileRevision!==revision)return;capability=parsed;$('file-name').textContent=file.name;}catch{$('status').textContent='File is not valid JSON.';}};
  $('resource-filter').oninput=()=>document.querySelectorAll('.resource').forEach(n=>n.hidden=!n.textContent.toLowerCase().includes($('resource-filter').value.toLowerCase()));
  for(const [id,checked] of [['select-all',true],['select-none',false]])$(id).onclick=()=>{document.querySelectorAll('#resources input').forEach(n=>n.checked=checked);clearExport();};
  $('public-security').onchange=()=>{$('api-key-fields').hidden=$('public-security').value!=='apiKey';$('oauth-fields').hidden=$('public-security').value!=='oauth2';};
  document.querySelector('main').addEventListener('input',event=>{if(!['resource-filter','endpoint','source-url','source-kind','source-auth','capability-file'].includes(event.target.id))clearExport();});
  $('include-metadata').checked=$('source-kind').value!=='file';
  $('inspect').onclick=()=>perform(false);$('generate').onclick=()=>perform(true);
  $('download-spec').onclick=()=>download(exported,'openapi.json');$('download-report').onclick=()=>download(report,'generation-report.json');
  try{const health=await api('health');csrf=health.csrfToken;$('environment').textContent=`${health.namespace} · ${health.version}`;if(!health.localAvailable){$('source-kind').value='file';$('source-kind').onchange();}}catch(error){$('environment').textContent='Login required';$('status').textContent=error.message;}
}
init();