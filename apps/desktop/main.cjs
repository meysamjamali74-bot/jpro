const { app, BrowserWindow, Menu, dialog } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const configPath = path.join(app.getPath('userData'), 'config.json');
function getUrl(){try{return JSON.parse(fs.readFileSync(configPath,'utf8')).url || 'http://localhost:8080'}catch{return process.env.TARAZPAD_WEB_URL || 'http://localhost:8080'}}
function createWindow(){const win=new BrowserWindow({width:1500,height:930,minWidth:1100,minHeight:700,backgroundColor:'#06142d',autoHideMenuBar:true,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}});win.loadURL(getUrl());win.webContents.setWindowOpenHandler(({url})=>{require('electron').shell.openExternal(url);return{action:'deny'}});return win}
app.whenReady().then(()=>{Menu.setApplicationMenu(null);const win=createWindow();win.webContents.on('did-fail-load',async()=>{const r=await dialog.showMessageBox(win,{type:'warning',title:'ترازپاد',message:'اتصال به سرور ترازپاد برقرار نشد.',detail:`آدرس فعلی: ${getUrl()}\nابتدا سرور وب را اجرا کنید یا فایل config.json را با آدرس سرور تنظیم کنید.`,buttons:['تلاش مجدد','بستن']});if(r.response===0)win.loadURL(getUrl());else app.quit()})});
app.on('window-all-closed',()=>{if(process.platform!=='darwin')app.quit()});
