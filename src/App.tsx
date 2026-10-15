import { useMemo, useState } from 'react'
import {
  AppWindow, Bell, Check, ChevronDown, CircleHelp, Command, GalleryHorizontalEnd,
  Grid2X2, Keyboard, Layers3, LayoutDashboard, Maximize2, Monitor, Moon,
  MousePointer2, Plus, RotateCcw, Settings2, SlidersHorizontal, Sparkles, X,
} from 'lucide-react'

type LayoutKey = 'focus' | 'triple' | 'quad' | 'center'
type WindowItem = { id: number; name: string; detail: string; color: string; icon: string }

const layouts: Record<LayoutKey, { name: string; ratio: string; columns: string; cells: number }> = {
  focus: { name: 'Focus + sides', ratio: '25 · 50 · 25', columns: '1fr 2fr 1fr', cells: 3 },
  triple: { name: 'Even thirds', ratio: '33 · 33 · 33', columns: '1fr 1fr 1fr', cells: 3 },
  quad: { name: 'Four columns', ratio: '25 · 25 · 25 · 25', columns: 'repeat(4, 1fr)', cells: 4 },
  center: { name: 'Wide center', ratio: '20 · 60 · 20', columns: '1fr 3fr 1fr', cells: 3 },
}

const initialWindows: WindowItem[] = [
  { id: 1, name: 'Figma', detail: 'Website explorations', color: '#9b83f6', icon: 'F' },
  { id: 2, name: 'Arc', detail: 'Research tabs', color: '#ef825f', icon: 'A' },
  { id: 3, name: 'Slack', detail: 'Design team', color: '#65b995', icon: 'S' },
]

const layoutKeys = Object.keys(layouts) as LayoutKey[]

export function App() {
  const [activeLayout, setActiveLayout] = useState<LayoutKey>('focus')
  const [workspace, setWorkspace] = useState('Design')
  const [windows, setWindows] = useState<WindowItem[]>(initialWindows)
  const [gap, setGap] = useState(10)
  const [scale, setScale] = useState(100)
  const [focusMode, setFocusMode] = useState(true)
  const [toast, setToast] = useState('')
  const [showShortcuts, setShowShortcuts] = useState(false)
  const [dragged, setDragged] = useState<number | null>(null)

  const layout = layouts[activeLayout]
  const cells = useMemo(() => Array.from({ length: layout.cells }), [layout.cells])

  const notify = (message: string) => {
    setToast(message)
    window.setTimeout(() => setToast(''), 2400)
  }

  const moveWindow = (target: number) => {
    if (dragged === null) return
    setWindows(current => {
      const from = current.findIndex(item => item.id === dragged)
      if (from < 0 || from === target) return current
      const next = [...current]
      const [item] = next.splice(from, 1)
      next.splice(target, 0, item)
      return next
    })
    setDragged(null)
    notify('Window moved')
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark"><GalleryHorizontalEnd size={20} strokeWidth={2.2} /></div>
          <span>Span</span>
        </div>

        <nav className="main-nav" aria-label="Main navigation">
          <button className="nav-item active"><LayoutDashboard size={18} /><span>Workspaces</span></button>
          <button className="nav-item"><Layers3 size={18} /><span>Layouts</span><span className="nav-count">4</span></button>
          <button className="nav-item"><Monitor size={18} /><span>Displays</span></button>
          <button className="nav-item"><Keyboard size={18} /><span>Shortcuts</span></button>
        </nav>

        <div className="sidebar-section">
          <p>Spaces</p>
          {['Design', 'Deep work', 'Communication'].map((name, index) => (
            <button key={name} className={`space-item ${workspace === name ? 'selected' : ''}`} onClick={() => setWorkspace(name)}>
              <span className={`space-dot dot-${index}`} />
              <span>{name}</span>
              {workspace === name && <Check size={14} />}
            </button>
          ))}
          <button className="add-space" onClick={() => notify('New space ready to name')}><Plus size={15} /> New space</button>
        </div>

        <div className="sidebar-bottom">
          <button className="nav-item"><CircleHelp size={18} /><span>Help</span></button>
          <button className="nav-item"><Settings2 size={18} /><span>Settings</span></button>
          <div className="profile">
            <div className="avatar">AN</div>
            <div><strong>Alex</strong><span>Span Pro</span></div>
            <ChevronDown size={15} />
          </div>
        </div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <div className="title-row"><h1>{workspace}</h1><span className="saved"><span /> Saved</span></div>
            <p>Odyssey G9 · 5120 × 1440 · 120 Hz</p>
          </div>
          <div className="top-actions">
            <button className="icon-button" aria-label="Notifications"><Bell size={18} /></button>
            <button className="shortcut-button" onClick={() => setShowShortcuts(true)}><Command size={16} /> Shortcuts</button>
            <button className="primary-button" onClick={() => notify('Workspace applied to Odyssey G9')}><Sparkles size={16} /> Apply workspace</button>
          </div>
        </header>

        <div className="content">
          <section className="monitor-section">
            <div className="section-heading">
              <div><h2>Your screen, mapped</h2><p>Drag windows between zones to arrange your workspace.</p></div>
              <button className="plain-button" onClick={() => { setWindows(initialWindows); setGap(10); notify('Layout reset') }}><RotateCcw size={15} /> Reset</button>
            </div>

            <div className="monitor-frame">
              <div className="camera-dot" />
              <div className="screen" style={{ gap: `${gap}px`, gridTemplateColumns: layout.columns }}>
                {cells.map((_, index) => {
                  const item = windows[index]
                  return (
                    <div
                      className={`zone ${dragged !== null ? 'drag-active' : ''}`}
                      key={`${activeLayout}-${index}`}
                      onDragOver={event => event.preventDefault()}
                      onDrop={() => moveWindow(index)}
                    >
                      <span className="zone-number">{index + 1}</span>
                      {item ? (
                        <div className="window-card" draggable onDragStart={() => setDragged(item.id)} onDragEnd={() => setDragged(null)}>
                          <div className="window-bar"><span /><span /><span /><MousePointer2 size={13} /></div>
                          <div className="window-body">
                            <div className="app-icon" style={{ background: item.color }}>{item.icon}</div>
                            <div><strong>{item.name}</strong><span>{item.detail}</span></div>
                          </div>
                          <div className="window-lines"><i /><i /><i /></div>
                        </div>
                      ) : <div className="empty-zone"><Plus size={18} /><span>Drop a window</span></div>}
                    </div>
                  )
                })}
              </div>
              <div className="monitor-label"><span>Odyssey G9</span><small>49-inch ultrawide</small></div>
            </div>
            <div className="monitor-stand"><span /></div>
          </section>

          <section className="controls-grid">
            <div className="panel layouts-panel">
              <div className="panel-heading"><div><h3>Zone layout</h3><p>Choose how the screen is divided.</p></div><button className="icon-button small" aria-label="Add layout"><Plus size={16} /></button></div>
              <div className="layout-options">
                {layoutKeys.map(key => (
                  <button key={key} className={`layout-option ${activeLayout === key ? 'active' : ''}`} onClick={() => setActiveLayout(key)}>
                    <span className="mini-layout" style={{ gridTemplateColumns: layouts[key].columns }}>
                      {Array.from({ length: layouts[key].cells }).map((_, i) => <i key={i} />)}
                    </span>
                    <span className="layout-copy"><strong>{layouts[key].name}</strong><small>{layouts[key].ratio}</small></span>
                    <span className="radio"><i /></span>
                  </button>
                ))}
              </div>
            </div>

            <div className="panel settings-panel">
              <div className="panel-heading"><div><h3>Display tuning</h3><p>Fine-tune this workspace.</p></div><SlidersHorizontal size={18} /></div>
              <label className="slider-row">
                <span><strong>Zone spacing</strong><small>{gap} px</small></span>
                <input type="range" min="0" max="24" value={gap} onChange={event => setGap(Number(event.target.value))} style={{ '--value': `${(gap / 24) * 100}%` } as React.CSSProperties} />
              </label>
              <label className="slider-row">
                <span><strong>Interface scale</strong><small>{scale}%</small></span>
                <input type="range" min="80" max="140" value={scale} onChange={event => setScale(Number(event.target.value))} style={{ '--value': `${((scale - 80) / 60) * 100}%` } as React.CSSProperties} />
              </label>
              <div className="divider" />
              <button className="toggle-row" onClick={() => setFocusMode(value => !value)}>
                <span className="setting-icon"><Moon size={17} /></span>
                <span className="toggle-copy"><strong>Focus mode</strong><small>Dim inactive zones while you work</small></span>
                <span className={`toggle ${focusMode ? 'on' : ''}`}><i /></span>
              </button>
              <button className="toggle-row" onClick={() => notify('App rules opened')}>
                <span className="setting-icon"><AppWindow size={17} /></span>
                <span className="toggle-copy"><strong>App rules</strong><small>3 apps assigned automatically</small></span>
                <span className="chevron">›</span>
              </button>
            </div>
          </section>
        </div>
      </section>

      {toast && <div className="toast"><Check size={16} />{toast}</div>}

      {showShortcuts && (
        <div className="modal-backdrop" onMouseDown={() => setShowShortcuts(false)}>
          <div className="modal" onMouseDown={event => event.stopPropagation()}>
            <div className="modal-header"><div><h2>Keyboard shortcuts</h2><p>Move at the speed of thought.</p></div><button className="icon-button" onClick={() => setShowShortcuts(false)}><X size={18} /></button></div>
            {[['Snap left', '⌃  ⌥  ←'], ['Snap right', '⌃  ⌥  →'], ['Maximize zone', '⌃  ⌥  ↩'], ['Switch workspace', '⌃  ⌥  1–3']].map(([label, keys]) => (
              <div className="shortcut-row" key={label}><span>{label}</span><kbd>{keys}</kbd></div>
            ))}
            <button className="primary-button full" onClick={() => setShowShortcuts(false)}>Done</button>
          </div>
        </div>
      )}
    </main>
  )
}
