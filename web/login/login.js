'use strict';
// Login page only establishes a session for the protected admin app; it does not read metadata or persist credentials.
document.getElementById('login').addEventListener('submit',async event=>{
  event.preventDefault();
  const user=document.getElementById('username'),password=document.getElementById('password'),button=document.getElementById('submit'),message=document.getElementById('message');
  const segment=location.pathname.split('/')[1];
  if(!segment.endsWith('_login')){message.textContent='Invalid login address.';return;}
  const target='/'+segment.slice(0,-6)+'/';
  const bytes=new TextEncoder().encode(user.value+':'+password.value);
  const credential=btoa(Array.from(bytes,b=>String.fromCharCode(b)).join(''));
  button.disabled=true;message.textContent='Signing in...';
  try{
    const response=await fetch(target+'api/v1/health',{credentials:'same-origin',headers:{Authorization:'Basic '+credential},cache:'no-store'});
    if(!response.ok)throw new Error(response.status===403?'Account has not been granted permission for this module.':'Incorrect username, password, or application permission.');
    password.value='';location.replace(target);
  }catch(error){message.textContent=error.message;}
  finally{password.value='';button.disabled=false;}
});