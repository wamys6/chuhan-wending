/* 预加载脚本：只暴露最小的桥，游戏逻辑保持纯浏览器可用 */
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('Desktop', {
  isDesktop: true,
  toggleFullscreen: function () { return ipcRenderer.invoke('fs-toggle'); },
  fullscreenState: function () { return ipcRenderer.invoke('fs-state'); }
});
