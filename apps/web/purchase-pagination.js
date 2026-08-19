(()=>{
  let page=1, meta={total:0,page:1,pageSize:50}, navigating=false;
  const originalFetch=window.fetch.bind(window);
  const isPurchaseInvoices=()=>document.querySelector('#pageTitle')?.textContent?.includes('فاکتورهای خرید');
  const fa=n=>new Intl.NumberFormat('fa-IR').format(Number(n||0));
  function updatePager(){
    if(!isPurchaseInvoices())return;
    const info=document.querySelector('#pagerInfo'),prev=document.querySelector('#prevPage'),next=document.querySelector('#nextPage');
    const pages=Math.max(1,Math.ceil(Number(meta.total||0)/Math.max(1,Number(meta.pageSize||50))));
    if(info)info.textContent=`صفحه ${fa(meta.page||page)} از ${fa(pages)} — ${fa(meta.total)} رکورد`;
    if(prev)prev.disabled=(meta.page||page)<=1;
    if(next)next.disabled=(meta.page||page)>=pages;
  }
  window.fetch=async function(input,init){
    const raw=typeof input==='string'?input:input?.url;
    if(raw){
      const url=new URL(raw,location.origin);
      if(url.pathname==='/api/iran/purchase-invoices'){
        const pageSize=Math.max(10,Math.min(200,Number(document.querySelector('#pageSize')?.value||50)));
        url.searchParams.set('page',String(page));
        url.searchParams.set('pageSize',String(pageSize));
        const response=await originalFetch(url.toString(),init);
        if(response.ok){
          try{
            const data=await response.clone().json();
            if(data&&Array.isArray(data.rows)){
              meta={total:Number(data.total||0),page:Number(data.page||page),pageSize:Number(data.pageSize||pageSize)};
              setTimeout(updatePager,0);
              return new Response(JSON.stringify(data.rows),{status:response.status,statusText:response.statusText,headers:response.headers});
            }
          }catch{}
        }
        return response;
      }
    }
    return originalFetch(input,init);
  };
  document.addEventListener('click',e=>{
    if(!isPurchaseInvoices())return;
    const id=e.target?.id;
    if(id!=='prevPage'&&id!=='nextPage')return;
    e.preventDefault();e.stopImmediatePropagation();
    const pages=Math.max(1,Math.ceil(Number(meta.total||0)/Math.max(1,Number(meta.pageSize||50))));
    const nextPage=id==='nextPage'?Math.min(pages,page+1):Math.max(1,page-1);
    if(nextPage===page)return;
    page=nextPage;navigating=true;
    const search=document.querySelector('#moduleSearch');
    if(search)search.dispatchEvent(new Event('input',{bubbles:true}));
    setTimeout(()=>{navigating=false},20);
  },true);
  const resetPage=e=>{
    if(!isPurchaseInvoices()||navigating)return;
    if(['moduleSearch','moduleFilter','classificationFilter','dateFrom','dateTo','pageSize'].includes(e.target?.id))page=1;
  };
  document.addEventListener('input',resetPage,true);
  document.addEventListener('change',e=>{
    resetPage(e);
    if(isPurchaseInvoices()&&e.target?.id==='pageSize'){
      const search=document.querySelector('#moduleSearch');
      if(search)search.dispatchEvent(new Event('input',{bubbles:true}));
    }
  },true);
  new MutationObserver(()=>setTimeout(updatePager,0)).observe(document.documentElement,{subtree:true,childList:true});
})();