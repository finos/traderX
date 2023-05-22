import { Component } from '@angular/core';
import { ThemeService } from './service/theme.service';

@Component({
    selector: 'app-root',
    templateUrl: './app.component.html',
    styleUrls: ['./app.component.scss']
})
export class AppComponent {

    constructor(public themeService: ThemeService) { }

}
