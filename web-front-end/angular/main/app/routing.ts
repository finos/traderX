import { Routes } from '@angular/router';
import { AboutComponent } from './about/about.component';
import { StatusComponent } from './status/status.component';
import { AccountComponent } from './accounts/account.component';
import { PageNotFoundComponent } from './page-not-found.component';
import { TradeComponent } from './trade/trade.component';

export const routes: Routes = [
    { path: 'about', component: AboutComponent },
    { path: 'status', component: StatusComponent },
    { path: 'trade', component: TradeComponent },
    { path: 'account', component: AccountComponent },
    { path: '', redirectTo: '/trade', pathMatch: 'full' }, // redirect to `first-component`
    { path: '**', component: PageNotFoundComponent }
];
