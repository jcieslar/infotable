const { execSync } = require('child_process');
const path = require('path');

// Helper to resolve gem path dynamically (works with path:, git:, and rubygems)
function resolveGemPath(gemName) {
  try {
    const bundlerCmd = `bundle show ${gemName}`;
    const gemPath = execSync(bundlerCmd, { encoding: 'utf-8' }).trim();
    return gemPath;
  } catch (error) {
    console.warn(`Warning: Could not resolve ${gemName} gem path:`, error.message);
    return null;
  }
}

const infotableGemPath = resolveGemPath('infotable');

// Build content paths
const contentPaths = [
  './app/javascript/**/*.js',
  './app/**/*.html.erb',
  './app/helpers/**/*.rb',
  './app/infotable/**/*.rb'
];

// Add infotable gem views if gem path is resolved
if (infotableGemPath) {
  contentPaths.push(path.join(infotableGemPath, 'app/views/infotable/**/*.{erb,rb}'));
  contentPaths.push(path.join(infotableGemPath, 'app/assets/javascripts/infotable/**/*.js'));
  contentPaths.push(path.join(infotableGemPath, 'lib/infotable/formatters/**/*.rb'));
  contentPaths.push(path.join(infotableGemPath, 'app/components/**/*.rb'));
  contentPaths.push(path.join(infotableGemPath, 'app/components/**/*.html.erb'));
}

module.exports = {
  content: contentPaths,
  theme: {
    extend: {
      fontFamily: {
        sans: [
          'Nunito',
          'ui-sans-serif',
          'system-ui',
          '-apple-system',
          'BlinkMacSystemFont',
          'Segoe UI',
          'Roboto',
          'Helvetica Neue',
          'Arial',
          'Noto Sans',
          'sans-serif',
          'Apple Color Emoji',
          'Segoe UI Emoji',
          'Segoe UI Symbol',
          'Noto Color Emoji',
        ],
      },
      colors: {
        transparent: 'transparent',
        current: 'currentColor',

        black: '#000',
        white: '#fff',

        purple: {
          50: '#DBCDDD',
          100: '#C3AABE',
          200: '#A787A1',
          300: '#9D6795',
          400: '#895482',
          500: '#7F4677',
          600: '#742669',
          700: '#691B5E',
          800: '#58114E',
          900: '#47023D',
        },
        primary: {
          50: '#F7F5FA',
          100: '#F0EAF6',
          200: '#D7C6E3',
          300: '#A887B5',
          400: '#835696',
          500: '#733982',
          600: '#701A75',
          700: '#5F1568',
          800: '#510761',
          900: '#4A044E',
        },

        blue: {
          50: '#E9F3F9',
          100: '#D8E9F2',
          200: '#C0DAE8',
          300: '#9ECDE6',
          400: '#63ADD4',
          500: '#2B8ABD',
          600: '#006DA7',
          700: '#075985',
          800: '#004164',
          900: '#002E47',
        },
        silver: {
          50: '#F6F8FA',
          100: '#F0F2F4',
          200: '#EAEDF0',
          300: '#E2E5E9',
          400: '#D0D8E1',
          500: '#C4CED9',
          600: '#B6BFCA',
          700: '#94A4B7',
          800: '#6A7D93',
          900: '#4D5F74',
        },
        gray: {
          50: '#F6F6F6',
          100: '#EFEFF0',
          200: '#E4E4E7',
          300: '#D7D7D7',
          400: '#CBCACA',
          500: '#AFAFAF',
          600: '#8C8C8C',
          700: '#6B6B6B',
          800: '#555555',
          900: '#3B3B3B',
        },
        'rating-green': {
          50: '#F3F8EC',
          100: '#E5F5CF',
          200: '#D2E9B4',
          300: '#C2DC9E',
          400: '#A9CE78',
          500: '#83B83D',
          600: '#53A925',
          700: '#04812A',
          800: '#006332',
          900: '#064E31',
        },
        pink: {
          50: '#F6EDF3',
          100: '#EAD1E0',
          200: '#D7A3C2',
          300: '#D078AD',
          400: '#D060A3',
          500: '#BD438C',
          600: '#AC2C78',
          700: '#9C0B62',
          800: '#880353',
          900: '#6B0040',
        },
        'rating-red': {
          50: '#FEF2F2',
          100: '#FEE2E2',
          200: '#FECACA',
          300: '#FCA5A5',
          400: '#F87171',
          500: '#EF444D',
          600: '#E31C37',
          700: '#BF1229',
          800: '#990317',
          900: '#7D0011',
        },
        red: {
          50: '#FFF5F3',
          100: '#FDE8E5',
          200: '#FCD9D3',
          300: '#FCBEB3',
          400: '#F99280',
          500: '#DD655A',
          600: '#D7443D',
          700: '#BD3730',
          800: '#A41008',
          900: '#710400',
        },
        yellow: {
          50: '#FFFBEB',
          100: '#FEF3C7',
          200: '#FDE68A',
          300: '#FCD34D',
          400: '#FBBF24',
          500: '#F59E0B',
          600: '#D97706',
          700: '#AA5B0B',
          800: '#924900',
          900: '#763B00',
        },

        gold: {
          50: '#FDFAF4',
          100: '#FFFAE9',
          200: '#F8EEDA',
          300: '#EFDCB4',
          400: '#E5C582',
          500: '#EDB745',
          600: '#E7A212',
          700: '#CA8A04',
          800: '#A16207',
          900: '#854D0E',
        },

        'rating-yellow': {
          50: '#FEF7ED',
          100: '#FBECD5',
          200: '#FDE3BA',
          300: '#F4D199',
          400: '#EFBA66',
          500: '#E9A333',
          600: '#E48D00',
          700: '#C86400',
          800: '#B15200',
          900: '#854D0E',
        },

        bronze: {
          50: '#FAFAF9',
          100: '#F6F4F3',
          200: '#F1EFEF',
          300: '#ECEAE9',
          400: '#E5DFDF',
          500: '#CEC3C0',
          600: '#B8A8A4',
          700: '#B1938C',
          800: '#96736A',
          900: '#825E55',
        },

        orange: {
          50: '#FEF0E6',
          100: '#FCE7D6',
          200: '#F9CEAD',
          300: '#F6AA71',
          400: '#F18533',
          500: '#EE6600',
          600: '#D75E02',
          700: '#B14C00',
          800: '#883B00',
          900: '#672C00',
        },

        green: {
          50: '#EDF7F2',
          100: '#D3EADF',
          200: '#B1D7C5',
          300: '#87BCA3',
          400: '#5CA482',
          500: '#399175',
          600: '#267767',
          700: '#0A635D',
          800: '#1E4443',
          900: '#072120',
        },

        tags: {
          50: '#E8EFF2',
          100: '#C1D8DE',
          200: '#A1BFC8',
          300: '#739EAC',
          400: '#3E90A6',
          500: '#0E7490',
          600: '#155E75',
          700: '#164E63',
          800: '#174253',
          900: '#002A3A',
        },
        'gray-purple': {
          50: '#F1F0F5',
          100: '#E2E0EA',
          200: '#D0CCE4',
          300: '#BFBBD1',
          400: '#B3A4C7',
          500: '#A082C9',
          600: '#8459A6',
          700: '#5E3181',
          800: '#2D1554',
          900: '#201633',
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms')({
      strategy: 'class',
    }),
  ],
}
