import { Injectable } from '@angular/core';

enum Themes {
    ProfessionalLight = 'professional-light',
    ProfessionalDark = 'professional-dark'
}

@Injectable({
    providedIn: 'root'
})
export class ThemeService {

    currentTheme = Themes.ProfessionalDark;

    switchTheme() {
        console.log('theme service');
        this.currentTheme = this.currentTheme === Themes.ProfessionalDark ? Themes.ProfessionalLight : Themes.ProfessionalDark;
        document.documentElement.className = this.currentTheme;
        const themeTag: any = document.querySelector('#theme-tag');
        themeTag.href = `${this.currentTheme}.css`;
    }

}
