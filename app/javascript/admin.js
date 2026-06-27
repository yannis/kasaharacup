import '@hotwired/turbo-rails';
import { Application } from '@hotwired/stimulus';
import FightWinnerController from './controllers/fight_winner_controller';
import LineupController from './controllers/lineup_controller';
import EncounterPanelController from './controllers/encounter_panel_controller';
import PoolMembershipController from './controllers/pool_membership_controller';
import StreamLinkController from './controllers/stream_link_controller';

const application = Application.start();
application.register('fight-winner', FightWinnerController);
application.register('lineup', LineupController);
application.register('encounter-panel', EncounterPanelController);
application.register('pool-membership', PoolMembershipController);
application.register('stream-link', StreamLinkController);
