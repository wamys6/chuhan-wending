/* Electron 主进程：窗口管理 + 全屏控制
 * 打开方式：
 *   npm start          —— 开发调试（带 DevTools 快捷键 F12）
 *   npm run dist       —— 打包 win-x64 免安装目录（Steam 用 dist/楚汉问鼎-win32-x64/）
 */
const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path = require('path');

const DEV = !app.isPackaged;
const WIN_W = 1440;
const WIN_H = 900;

/* 游戏页面有 BGM 定时器和动画：窗口被遮挡/最小化时禁止 Chromium 节流，否则音乐会卡死 */
app.commandLine.appendSwitch('disable-features', 'CalculateNativeWinOcclusion');

let win = null;

function createWindow() {
  win = new BrowserWindow({
    width: WIN_W,
    height: WIN_H,
    minWidth: 1100,
    minHeight: 700,
    title: '楚汉·问鼎',
    backgroundColor: '#f4efe3',
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'electron-preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      backgroundThrottling: false,
      spellcheck: false
    }
  });

  win.loadFile('index.html');

  win.once('ready-to-show', function () { win.show(); });

  /* 页面内点击外链用系统浏览器打开，不留窗口内导航漏洞 */
  win.webContents.setWindowOpenHandler(function (d) {
    shell.openExternal(d.url);
    return { action: 'deny' };
  });

  if (DEV) {
    win.webContents.on('before-input-event', function (e, input) {
      if (input.type === 'keyDown' && input.key === 'F12') {
        win.webContents.toggleDevTools();
      }
    });
  }

  win.on('closed', function () { win = null; });
}

/* 设置面板里的全屏按钮 → 走原生全屏（体验比网页 Fullscreen API 稳） */
ipcMain.handle('fs-toggle', function () {
  if (!win) return false;
  win.setFullScreen(!win.isFullScreen());
  return win.isFullScreen();
});
ipcMain.handle('fs-state', function () {
  return win ? win.isFullScreen() : false;
});

app.whenReady().then(function () {
  createWindow();
  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', function () {
  app.quit();
});
