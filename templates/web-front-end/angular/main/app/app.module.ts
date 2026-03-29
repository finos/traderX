import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { AppComponent } from './app.component';
import { TradeModule } from './trade/trade.module';
import { provideHttpClient, withInterceptorsFromDi, withJsonpSupport } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { AgGridModule } from 'ag-grid-angular';
import { HeaderComponent } from './header/header.component';
import { AccountsModule } from './accounts/accounts.module';
import { RouterModule } from '@angular/router';
import { routes } from './routing';
import { PageNotFoundComponent } from './page-not-found.component';

@NgModule({ declarations: [AppComponent, HeaderComponent, PageNotFoundComponent],
    bootstrap: [AppComponent], imports: [BrowserModule,
        CommonModule,
        TradeModule,
        AccountsModule,
        AgGridModule,
        RouterModule.forRoot(routes)], providers: [provideHttpClient(withInterceptorsFromDi(), withJsonpSupport())] })
export class AppModule { }
