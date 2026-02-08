import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = 'https://mzgtvdgwxrlhgjboolys.supabase.co';
const MAPS_API_KEY = 'AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ';

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get('token');
  if (!token) {
    return new Response(
      '<?xml version="1.0" encoding="UTF-8"?><html xmlns="http://www.w3.org/1999/xhtml"><body><h1>Gecersiz link</h1></body></html>',
      { status: 400, headers: { 'Content-Type': 'text/xml; charset=utf-8' } }
    );
  }

  // Build the actual HTML page (runs inside iframe as proper text/html)
  const htmlPage = `<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>Canli Yolculuk Takibi</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f5f5f5;overflow:hidden}
#map{width:100%;height:100vh}
#info{position:fixed;bottom:0;left:0;right:0;background:#fff;border-radius:20px 20px 0 0;box-shadow:0 -4px 20px rgba(0,0,0,0.15);padding:20px;z-index:10;max-height:45vh;overflow-y:auto}
#info .handle{width:40px;height:4px;background:#ddd;border-radius:2px;margin:0 auto 16px}
.status-badge{display:inline-flex;align-items:center;gap:6px;padding:6px 14px;border-radius:20px;font-size:13px;font-weight:600}
.status-active{background:#e8f5e9;color:#2e7d32}
.status-completed{background:#e3f2fd;color:#1565c0}
.status-cancelled{background:#fbe9e7;color:#c62828}
.driver-info{display:flex;align-items:center;gap:12px;margin:12px 0;padding:12px;background:#f8f9fa;border-radius:12px}
.driver-avatar{width:48px;height:48px;border-radius:50%;background:#e3f2fd;display:flex;align-items:center;justify-content:center;font-size:20px;font-weight:700;color:#1565c0}
.driver-name{font-size:16px;font-weight:600;color:#1a1a1a}
.driver-vehicle{font-size:13px;color:#666;margin-top:2px}
.driver-plate{display:inline-block;padding:2px 8px;background:#f0f0f0;border-radius:4px;font-family:monospace;font-size:13px;font-weight:600;margin-top:4px}
.route-info{display:flex;gap:8px;margin-top:12px}
.route-point{flex:1;padding:10px;background:#f8f9fa;border-radius:10px}
.route-label{font-size:11px;color:#999;text-transform:uppercase;letter-spacing:0.5px}
.route-address{font-size:13px;color:#333;margin-top:4px;line-height:1.3}
.dot{width:8px;height:8px;border-radius:50%;display:inline-block;margin-right:6px}
.dot-green{background:#4caf50}
.dot-red{background:#f44336}
#loading{position:fixed;top:0;left:0;right:0;bottom:0;background:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;z-index:100}
.spinner{width:40px;height:40px;border:3px solid #e0e0e0;border-top-color:#1976d2;border-radius:50%;animation:spin 0.8s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
#loading p{margin-top:16px;color:#666;font-size:14px}
#ended{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.6);z-index:200;align-items:center;justify-content:center}
#ended .card{background:#fff;border-radius:20px;padding:32px;text-align:center;margin:20px;max-width:340px}
#ended .card h2{font-size:20px;margin:12px 0 8px}
#ended .card p{color:#666;font-size:14px}
.icon{font-size:48px}
</style>
</head>
<body>
<div id="loading"><div class="spinner"></div><p>Yolculuk bilgileri yukleniyor...</p></div>
<div id="ended"><div class="card"><div class="icon">&#10004;</div><h2 id="ended-title">Yolculuk Tamamlandi</h2><p id="ended-msg">Bu yolculuk sona ermistir.</p></div></div>
<div id="map"></div>
<div id="info" style="display:none">
<div class="handle"></div>
<div id="status-container"></div>
<div id="driver-container"></div>
<div id="route-container"></div>
</div>
<script>
var TOKEN='${token}';
var API='${SUPABASE_URL}/functions/v1/secure-communication';
var map,driverMarker;

function fetchRide(){
  return fetch(API,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'get_shared_ride',share_token:TOKEN})})
  .then(function(r){return r.json()})
  .then(function(d){if(!d.success||!d.data)return null;return d.data})
  .catch(function(e){console.error('fetchRide error:',e);return null});
}

function statusText(s){
  var m={pending:'Surucu Araniyor',accepted:'Surucu Yolda',arrived:'Surucu Bekliyor',in_progress:'Yolculukta',completed:'Tamamlandi',cancelled:'Iptal Edildi'};
  return m[s]||s;
}

function statusClass(s){return s==='completed'?'status-completed':s==='cancelled'?'status-cancelled':'status-active'}

function updateUI(d){
  document.getElementById('loading').style.display='none';
  var st=d.ride_status||d.status;
  if(st==='completed'||st==='cancelled'){
    var e=document.getElementById('ended');
    e.style.display='flex';
    document.getElementById('ended-title').textContent=st==='completed'?'Yolculuk Tamamlandi':'Yolculuk Iptal Edildi';
    document.getElementById('ended-msg').textContent=st==='completed'?'Yolcu guvenle hedefine ulasti.':'Bu yolculuk iptal edilmistir.';
    return false;
  }
  document.getElementById('info').style.display='block';
  document.getElementById('status-container').innerHTML='<span class="status-badge '+statusClass(st)+'">'+statusText(st)+'</span>';
  if(d.driver_name){
    var initials=d.driver_name.split(' ').map(function(n){return n[0]}).join('').substring(0,2);
    var h='<div class="driver-info"><div class="driver-avatar">'+initials+'</div><div>';
    h+='<div class="driver-name">'+d.driver_name+'</div>';
    if(d.vehicle_info)h+='<div class="driver-vehicle">'+d.vehicle_info+'</div>';
    if(d.vehicle_plate)h+='<div class="driver-plate">'+d.vehicle_plate+'</div>';
    h+='</div></div>';
    document.getElementById('driver-container').innerHTML=h;
  }
  var r='<div class="route-info">';
  if(d.pickup_address)r+='<div class="route-point"><div class="route-label"><span class="dot dot-green"></span>Alis</div><div class="route-address">'+d.pickup_address+'</div></div>';
  if(d.dropoff_address)r+='<div class="route-point"><div class="route-label"><span class="dot dot-red"></span>Varis</div><div class="route-address">'+d.dropoff_address+'</div></div>';
  r+='</div>';
  document.getElementById('route-container').innerHTML=r;
  return true;
}

function updateMap(d){
  var lat=d.current_lat||d.driver_latitude;
  var lng=d.current_lng||d.driver_longitude;
  if(!lat||!lng)return;
  var pos={lat:lat,lng:lng};
  if(!driverMarker){
    driverMarker=new google.maps.Marker({position:pos,map:map,icon:{path:google.maps.SymbolPath.FORWARD_CLOSED_ARROW,scale:7,fillColor:'#1976d2',fillOpacity:1,strokeColor:'#fff',strokeWeight:2,rotation:0},zIndex:10,title:'Surucu'});
    map.panTo(pos);map.setZoom(16);
  }else{
    driverMarker.setPosition(pos);
  }
}

window.initMap=function(){
  fetchRide().then(function(d){
    if(!d){
      document.getElementById('loading').innerHTML='<p>Yolculuk bulunamadi veya link suresi dolmus.</p>';
      return;
    }
    var lat=d.current_lat||d.driver_latitude||35.185;
    var lng=d.current_lng||d.driver_longitude||33.382;
    map=new google.maps.Map(document.getElementById('map'),{center:{lat:lat,lng:lng},zoom:14,disableDefaultUI:true,zoomControl:true});
    updateUI(d);
    updateMap(d);
    setInterval(function(){fetchRide().then(function(nd){if(nd){var c=updateUI(nd);if(c)updateMap(nd)}})},5000);
  });
};
</script>
<script src="https://maps.googleapis.com/maps/api/js?key=${MAPS_API_KEY}&callback=initMap" async defer></script>
</body>
</html>`;

  // Escape HTML for XML srcdoc attribute
  const escaped = htmlPage
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

  // Wrap in minimal XHTML served as text/xml to bypass Supabase gateway's text/html -> text/plain rewrite
  // The actual page runs inside an iframe (srcdoc) as proper text/html
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="UTF-8" />
<title>Canli Yolculuk Takibi</title>
<style>*{margin:0;padding:0}body,html{width:100%;height:100%;overflow:hidden}iframe{width:100%;height:100%;border:none}</style>
</head>
<body>
<iframe srcdoc="${escaped}" style="width:100vw;height:100vh;border:none" allowfullscreen="true">&#160;</iframe>
</body>
</html>`;

  return new Response(xml, {
    headers: { 'Content-Type': 'text/xml; charset=utf-8' },
  });
});
