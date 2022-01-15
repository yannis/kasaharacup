const colors = require('tailwindcss/colors');

module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/components/**/*.html.erb',
    './app/components/**/*.rb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
  ],
  theme: {
    backgroundColor: (theme) => ({
      ...theme('colors'),
    }),
    colors: {
      transparent: 'transparent',
      current: 'currentColor',
      black: colors.black,
      white: colors.white,
      gray: colors.gray,
      red: colors.red,
      yellow: colors.yellow,
      green: colors.green,
      indigo: colors.indigo,
    },
    extend: {
      colors: {
        brand: {
          lightest: '#fef6ef',
          lighter: '#e5c9b1',
          light: '#eb862e',
          DEFAULT: '#de7012',
          dark: '#d16a0f',
        },
        positive: {
          light: '#8fbb67',
          DEFAULT: '#80ac57',
          dark: '#7eac53',
        },
        gray: {
          50: '#FCFAF8',
          100: '#F5F3F1',
          200: '#E8E5E3',
          300: '#D6D4D0',
          400: '#A6A29D',
          500: '#75716C',
          600: '#57524F',
          700: '#44403A',
          800: '#27231F',
          900: '#181512',
        },
        red: {
          50: '#fcb7ad',
          100: '#fba698',
          200: '#fa9483',
          300: '#f9826f',
          400: '#f9705a',
          500: '#f85e46',
          600: '#F74C31',
          700: '#c72208',
          800: '#ab1d07',
          900: '#8e1806',

        },
      },
      fontFamily: {
        // sans: 'Inter, sans-serif',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'), // eslint-disable-line global-require
    require('@tailwindcss/typography'), // eslint-disable-line global-require
  ],
};
