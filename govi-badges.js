/* GOVI OFFICIAL BADGES · isolated UI module; does not replace existing app handlers */
(()=> {
  'use strict';
  const FOUNDER_ID='5e631491-4c29-4e8d-9aff-0e40bcd3b7f9';
  const BADGE_CLASS='govi-official-badge';
  const style=document.createElement('style');
  style.textContent=`
    .${BADGE_CLASS}{display:inline-flex!important;align-items:center!important;justify-content:center!important;width:16px!important;height:16px!important;min-width:16px!important;vertical-align:middle!important;margin-left:5px!important;border-radius:50%!important;background:#19b96b!important;color:#fff!important;font:900 11px/1 Arial,sans-serif!important;box-shadow:0 0 0 1.5px #101713!important;flex:0 0 16px!important}
    .${BADGE_CLASS}[data-badge-type="founder"]{background:#19b96b!important}
  `;
  document.head.appendChild(style);
  let badgeMap=new Map();
  const client=()=>window.supabaseClient||(typeof supabaseClient!=='undefined'?supabaseClient:null);
  const current=()=>typeof currentUser!=='undefined'?currentUser:null;
  function addBadge(el,type){
    if(!el||el.querySelector(':scope > .'+BADGE_CLASS))return;
    const b=document.createElement('span');
    b.className=BADGE_CLASS;b.dataset.badgeType=type;b.setAttribute('aria-label',type==='founder'?'Fundador de GOVI':'Cuenta oficial GOVI');b.title=type==='founder'?'Fundador de GOVI':'Cuenta oficial GOVI';b.textContent='✓';
    el.appendChild(b);
  }
  function decorate(){
    const me=current();
    document.querySelectorAll('[data-user-id]').forEach(el=>{
      const id=el.getAttribute('data-user-id');if(!id)return;
      const type=id===FOUNDER_ID?'founder':badgeMap.get(id);
      if(!type)return;
      if(el.matches('.post-author,b,[style*="cursor:pointer"]'))addBadge(el,type);
    });
    const profileName=document.getElementById('goviProfileName');
    const profileId=(typeof goviProfileId!=='undefined'?goviProfileId:null)||(window.goviProfileId)||(me&&me.id);
    const type=profileId===FOUNDER_ID?'founder':badgeMap.get(profileId);
    if(profileName&&type)addBadge(profileName,type);
  }
  async function loadBadges(){
    const db=client();if(!db)return;
    try{
      const {data,error}=await db.from('govi_verified_badges').select('user_id,badge_type').eq('status','active');
      if(error)throw error;
      badgeMap=new Map((data||[]).map(x=>[x.user_id,x.badge_type]));
      decorate();
    }catch(e){console.warn('GOVI insignias: no se pudieron cargar todavía',e)}
  }
  const observer=new MutationObserver(()=>decorate());
  observer.observe(document.documentElement,{childList:true,subtree:true});
  document.addEventListener('DOMContentLoaded',()=>{loadBadges();setTimeout(loadBadges,1200)});
  window.addEventListener('govi:profile-opened',decorate);
  if(document.readyState!=='loading'){loadBadges();setTimeout(loadBadges,1200)}
  window.goviRefreshOfficialBadges=loadBadges;
})();