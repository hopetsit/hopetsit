const render = (template, vars = {}) => {
  if (typeof template !== 'string' || !template) return '';
  return template.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (_, path) => {
    const parts = path.split('.');
    let cur = vars;
    for (const p of parts) {
      if (cur == null) return '';
      cur = cur[p];
    }
    return cur == null ? '' : String(cur);
  });
};

module.exports = { render };
