
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');
const postcss = require('postcss');
const css = require('css');
const sortCSSmq = require('sort-css-media-queries');

async function mergeAndSortStyles(filePath) {
  try {
    // Read and parse the HTML file
    const htmlContent = fs.readFileSync(filePath, 'utf8');
    const dom = new JSDOM(htmlContent);
    const document = dom.window.document;

    // Extract all style elements
    const styleElements = [...document.querySelectorAll('style')];
    const allStyles = styleElements.map(el => el.textContent).join('\n');

    // Parse CSS rules from all styles
    const parsedCSS = css.parse(allStyles);
    const { stylesheet } = parsedCSS;
    const { rules } = stylesheet;

    // Categorize CSS rules
    const elementRules = [];
    const classRules = [];
    const idRules = [];

    rules.forEach(rule => {
      rule.selectors.forEach(selector => {
        if (selector.startsWith('#')) {
          idRules.push(rule);
        } else if (selector.startsWith('.')) {
          classRules.push(rule);
        } else {
          elementRules.push(rule);
        }
      });
    });

    // Sort alphabetically within each category
    const sortAlphabetically = arr => arr.sort((a, b) =>
      a.selectors[0].localeCompare(b.selectors[0]));
    sortAlphabetically(elementRules);
    sortAlphabetically(classRules);
    sortAlphabetically(idRules);

    // Combine sorted rules
    const sortedRules = [...elementRules, ...classRules, ...idRules];

    // Create new sorted stylesheet
    const sortedCSS = css.stringify({
      type: stylesheet.type,
      stylesheet: { rules: sortedRules }
    });

    // Remove all existing style blocks
    styleElements.forEach(el => el.remove());

    // Add new sorted style block
    const sortedStyleElement = document.createElement('style');
    sortedStyleElement.textContent = sortedCSS;
    document.head.appendChild(sortedStyleElement);

    // Write new HTML file
    fs.writeFileSync(filePath, dom.serialize());

    console.log(`Styles merged and sorted for file: ${filePath}`);
  } catch (error) {
    console.error(`Error processing the file: ${error.message}`);
  }
}

// Path to your HTML file
const inputFilePath = path.resolve(__dirname, 'input.html');
mergeAndSortStyles(inputFilePath);
