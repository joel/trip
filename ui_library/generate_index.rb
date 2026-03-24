#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates ui_library/index.html from YAML entries and component source files.
# Run: ruby ui_library/generate_index.rb

require "yaml"
require "json"
require "cgi"

PROJECT_ROOT = File.expand_path("..", __dir__)
UI_LIBRARY_DIR = File.join(PROJECT_ROOT, "ui_library")
COMPONENTS_DIR = File.join(PROJECT_ROOT, "app", "components")
VIEWS_DIR = File.join(PROJECT_ROOT, "app", "views")

# Collect all YAML entries
entries = Dir.glob(File.join(UI_LIBRARY_DIR, "*.yml")).map do |path|
  data = YAML.load_file(path)
  source_path = File.join(PROJECT_ROOT, data["file"])
  data["source_code"] = File.exist?(source_path) ? File.read(source_path) : "# File not found: #{data["file"]}"
  data["yml_name"] = File.basename(path, ".yml")
  data
end

# Build CONTENT hash: component_name => source_code
content = {}
entries.each { |e| content[e["yml_name"]] = e["source_code"] }

# Build COMPONENTS tree grouped by type
types = entries.group_by do |e|
  case e["yml_name"]
  when /badge/ then "Badges"
  when /card/ then "Cards"
  when /form/ then "Forms"
  when /sidebar|nav_item/ then "Navigation"
  when /header/ then "Headings"
  when /banner|flash|toast/ then "Feedback"
  when /rodauth/ then "Authentication"
  else "Other"
  end
end

components_tree = {}
types.sort.each do |type, items|
  components_tree[type] = items.map { |e| e["yml_name"] }
end

# Build metadata for detail panel
meta = {}
entries.each do |e|
  meta[e["yml_name"]] = {
    "component" => e["component"],
    "file" => e["file"],
    "library_source" => e["library_source"],
    "library_variant" => e["library_variant"],
    "description" => e["description"],
    "design_tokens" => e["design_tokens"] || [],
    "tailwind_classes" => e["tailwind_classes"] || []
  }
end

html = <<~HTML
  <!DOCTYPE html>
  <html lang="en" class="h-full">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Catalyst UI Library</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
      [data-tree-toggle] { cursor: pointer; user-select: none; }
      .tree-children { display: block; }
      .nav-link.active { background-color: rgb(238 242 255); color: rgb(79 70 229); }
      .dark .nav-link.active { background-color: rgb(49 46 89); color: rgb(165 160 255); }
      #sidebar::-webkit-scrollbar { width: 6px; }
      #sidebar::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 3px; }
      pre { white-space: pre-wrap; word-wrap: break-word; }
      .token-badge { display: inline-block; padding: 2px 8px; border-radius: 6px; font-size: 12px; font-family: ui-monospace, monospace; }
    </style>
  </head>
  <body class="h-full bg-gray-50 dark:bg-gray-950">
    <div class="flex h-full">
      <aside id="sidebar" class="w-72 shrink-0 border-r border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 overflow-y-auto flex flex-col">
        <div class="sticky top-0 z-10 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800 p-4">
          <h1 class="text-lg font-bold text-gray-900 dark:text-white">Catalyst UI Library</h1>
          <p id="count" class="mt-1 text-sm text-gray-500"></p>
          <div class="relative mt-3">
            <svg class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
            </svg>
            <input id="search" type="text" placeholder="Search..."
              class="w-full rounded-lg border border-gray-300 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 pl-10 pr-3 py-2 text-sm text-gray-900 dark:text-white placeholder-gray-400 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none" />
          </div>
        </div>
        <nav id="tree" class="flex-1 p-2 space-y-0.5"></nav>
      </aside>

      <main class="flex-1 overflow-y-auto">
        <div id="welcome" class="flex items-center justify-center h-full">
          <div class="text-center max-w-md">
            <div class="mx-auto w-16 h-16 rounded-2xl bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center mb-4">
              <svg class="w-8 h-8 text-indigo-600 dark:text-indigo-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.429 9.75 2.25 12l4.179 2.25m0-4.5 5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L12 12.75 6.429 9.75m11.142 0 4.179 2.25L12 17.25 2.25 12l4.179-2.25m11.142 0 4.179 2.25L12 22.5l-9.75-5.25 4.179-2.25" />
              </svg>
            </div>
            <h2 class="text-xl font-semibold text-gray-900 dark:text-white">Catalyst UI Library</h2>
            <p class="mt-2 text-gray-500 dark:text-gray-400">Select a component from the sidebar to view its source code, design tokens, and library mapping.</p>
          </div>
        </div>

        <div id="detail" class="hidden">
          <div class="sticky top-0 z-10 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800 px-6 py-3 flex items-center justify-between">
            <div>
              <p id="comp-name" class="text-lg font-semibold text-gray-900 dark:text-white"></p>
              <p id="comp-file" class="text-sm text-gray-500 font-mono"></p>
            </div>
            <div class="flex gap-2">
              <button id="btn-source" class="px-3 py-1.5 text-sm font-medium rounded-lg bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300 hover:bg-indigo-100 dark:hover:bg-indigo-900/50">Source</button>
              <button id="btn-meta" class="px-3 py-1.5 text-sm font-medium rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700">Details</button>
            </div>
          </div>

          <div id="view-source" class="p-6">
            <pre id="source-code" class="rounded-xl bg-gray-900 text-gray-100 p-6 text-sm font-mono overflow-x-auto leading-relaxed"></pre>
          </div>

          <div id="view-meta" class="hidden p-6 space-y-6">
            <div>
              <h3 class="text-sm font-semibold text-gray-900 dark:text-white uppercase tracking-wider mb-2">Description</h3>
              <p id="meta-desc" class="text-gray-600 dark:text-gray-400"></p>
            </div>
            <div>
              <h3 class="text-sm font-semibold text-gray-900 dark:text-white uppercase tracking-wider mb-2">Library Source</h3>
              <p id="meta-lib" class="text-gray-600 dark:text-gray-400 font-mono text-sm"></p>
            </div>
            <div>
              <h3 class="text-sm font-semibold text-gray-900 dark:text-white uppercase tracking-wider mb-2">Design Tokens</h3>
              <div id="meta-tokens" class="flex flex-wrap gap-2"></div>
            </div>
            <div>
              <h3 class="text-sm font-semibold text-gray-900 dark:text-white uppercase tracking-wider mb-2">Tailwind Classes</h3>
              <div id="meta-tw" class="flex flex-wrap gap-2"></div>
            </div>
          </div>
        </div>
      </main>
    </div>

  <script>
  const COMPONENTS = #{JSON.generate(components_tree)};
  const CONTENT = #{JSON.generate(content)};
  const META = #{JSON.generate(meta)};

  const allFiles = Object.values(COMPONENTS).flat();
  const treeEl = document.getElementById('tree');
  const searchEl = document.getElementById('search');
  const countEl = document.getElementById('count');
  const welcomeEl = document.getElementById('welcome');
  const detailEl = document.getElementById('detail');
  const compNameEl = document.getElementById('comp-name');
  const compFileEl = document.getElementById('comp-file');
  const sourceCodeEl = document.getElementById('source-code');
  const viewSourceEl = document.getElementById('view-source');
  const viewMetaEl = document.getElementById('view-meta');
  const btnSource = document.getElementById('btn-source');
  const btnMeta = document.getElementById('btn-meta');

  countEl.textContent = allFiles.length + ' components';

  function humanize(s) {
    return s.replace(/_/g, ' ').replace(/\\b\\w/g, c => c.toUpperCase());
  }

  function buildTree(data, container) {
    for (const [group, files] of Object.entries(data)) {
      const header = document.createElement('div');
      header.className = 'px-2 pt-3 pb-1 text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider';
      header.textContent = group + ' (' + files.length + ')';
      container.appendChild(header);

      for (const file of files) {
        const link = document.createElement('a');
        link.href = '#' + file;
        link.className = 'nav-link block py-1.5 px-3 rounded-lg text-sm text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 truncate';
        link.textContent = humanize(file);
        link.dataset.file = file;
        link.addEventListener('click', function(e) {
          e.preventDefault();
          loadComponent(file);
          history.replaceState(null, '', '#' + file);
        });
        container.appendChild(link);
      }
    }
  }

  function loadComponent(file) {
    const code = CONTENT[file];
    const m = META[file];
    if (!code || !m) return;

    treeEl.querySelectorAll('.nav-link').forEach(el => el.classList.remove('active'));
    const active = treeEl.querySelector('[data-file="' + file + '"]');
    if (active) { active.classList.add('active'); active.scrollIntoView({ block: 'nearest' }); }

    compNameEl.textContent = m.component;
    compFileEl.textContent = m.file;
    sourceCodeEl.textContent = code;

    document.getElementById('meta-desc').textContent = m.description || 'No description';
    document.getElementById('meta-lib').textContent = m.library_source ? m.library_source + (m.library_variant ? '/' + m.library_variant : '') : 'Custom (no library source)';

    const tokensEl = document.getElementById('meta-tokens');
    tokensEl.innerHTML = '';
    (m.design_tokens || []).forEach(t => {
      const badge = document.createElement('span');
      badge.className = 'token-badge bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300';
      badge.textContent = t;
      tokensEl.appendChild(badge);
    });
    if (!m.design_tokens || m.design_tokens.length === 0) {
      tokensEl.innerHTML = '<span class="text-sm text-gray-400">None</span>';
    }

    const twEl = document.getElementById('meta-tw');
    twEl.innerHTML = '';
    (m.tailwind_classes || []).forEach(t => {
      const badge = document.createElement('span');
      badge.className = 'token-badge bg-emerald-50 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300';
      badge.textContent = t;
      twEl.appendChild(badge);
    });

    welcomeEl.classList.add('hidden');
    detailEl.classList.remove('hidden');
    showSource();
  }

  function showSource() {
    viewSourceEl.classList.remove('hidden');
    viewMetaEl.classList.add('hidden');
    btnSource.className = 'px-3 py-1.5 text-sm font-medium rounded-lg bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300';
    btnMeta.className = 'px-3 py-1.5 text-sm font-medium rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700';
  }

  function showMeta() {
    viewSourceEl.classList.add('hidden');
    viewMetaEl.classList.remove('hidden');
    btnMeta.className = 'px-3 py-1.5 text-sm font-medium rounded-lg bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300';
    btnSource.className = 'px-3 py-1.5 text-sm font-medium rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700';
  }

  btnSource.addEventListener('click', showSource);
  btnMeta.addEventListener('click', showMeta);

  searchEl.addEventListener('input', function() {
    const q = searchEl.value.trim().toLowerCase();
    treeEl.innerHTML = '';
    if (!q) { buildTree(COMPONENTS, treeEl); countEl.textContent = allFiles.length + ' components'; return; }

    const matches = allFiles.filter(f => f.replace(/_/g, ' ').toLowerCase().includes(q));
    countEl.textContent = matches.length + ' of ' + allFiles.length;

    if (matches.length === 0) { treeEl.innerHTML = '<p class="text-gray-400 px-2 py-4 text-center text-sm">No matches</p>'; return; }
    const grouped = {};
    for (const f of matches) {
      for (const [g, files] of Object.entries(COMPONENTS)) {
        if (files.includes(f)) { (grouped[g] = grouped[g] || []).push(f); break; }
      }
    }
    buildTree(grouped, treeEl);
  });

  buildTree(COMPONENTS, treeEl);

  if (location.hash) { loadComponent(location.hash.slice(1)); }
  </script>
  </body>
  </html>
HTML

output_path = File.join(UI_LIBRARY_DIR, "index.html")
File.write(output_path, html)
puts "Generated #{output_path} with #{entries.size} components"
