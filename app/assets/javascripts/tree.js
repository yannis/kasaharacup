
window.Tree = {
  depth: 0,
  elements: null,
  branchNumber: 0,
  paper: null,
  initial_position: null,
  init: function() {
    var baseElement;
    baseElement = $('#category-tree-drawing');
    if (baseElement.length) {
      this.elements = baseElement.data('treeElements');
      this.depth = baseElement.data('treeDepth');
      this.branchNumber = baseElement.data('treeBranchNumber');
      this.paper = new Raphael(document.getElementById('category-tree-drawing'), 150 * this.depth + 100, 50 * this.branchNumber + 1);
      this.initial_position = {
        x: 0,
        y: 0
      };
      this.draw_tree();
      console.log("depth", this.depth);
      return console.log("branchNumber", this.branchNumber);
    }
  },
  draw_tree: function() {
    var branch, branchHeight, branchLength, element, l_x, l_y, level, m_x, m_y, numberOfBranchToDraw, zoneHeight, _ref, _results;
    console.log("@elements[0]", this.elements[0]);
    _results = [];
    for (level = 0, _ref = this.depth; 0 <= _ref ? level <= _ref : level >= _ref; 0 <= _ref ? level++ : level--) {
      numberOfBranchToDraw = Math.pow(2, level);
      branchLength = 100;
      zoneHeight = this.paper.height / numberOfBranchToDraw;
      branchHeight = this.paper.height / (numberOfBranchToDraw * 2);
      _results.push((function() {
        var _results2;
        _results2 = [];
        for (branch = 1; 1 <= numberOfBranchToDraw ? branch <= numberOfBranchToDraw : branch >= numberOfBranchToDraw; 1 <= numberOfBranchToDraw ? branch++ : branch--) {
          m_x = this.paper.width - (level * 150);
          m_y = ((branch - 1) * zoneHeight) + zoneHeight / 2;
          l_x = -100;
          l_y = 0;
          this.paper.path("M " + m_x + " " + m_y + " l " + l_x + " " + l_y);
          if (level === this.depth) {
            element = this.elements[branch - 1];
            if (element) this.paper.text(0 + 40, m_y - 6, element);
          }
          if (level > 0 && branch % 2 === 1) {
            m_x = m_x;
            m_y = m_y;
            l_x = 50;
            l_y = zoneHeight / 2;
            _results2.push(this.paper.path("M " + m_x + " " + m_y + " l " + l_x + " " + l_y));
          } else {
            m_x = m_x;
            m_y = m_y;
            l_x = 50;
            l_y = -zoneHeight / 2;
            _results2.push(this.paper.path("M " + m_x + " " + m_y + " l " + l_x + " " + l_y));
          }
        }
        return _results2;
      }).call(this));
    }
    return _results;
  }
};

$(function() {
  return Tree.init();
});
