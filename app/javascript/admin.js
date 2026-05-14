import '@hotwired/turbo-rails';
import { Application } from '@hotwired/stimulus';
import FightWinnerController from './controllers/fight_winner_controller';

const application = Application.start();
application.register('fight-winner', FightWinnerController);
