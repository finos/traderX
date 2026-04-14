import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { Observable } from 'rxjs';
import { StateUiMetadata } from '../model/state-ui-metadata.model';
import { StateMetadataService } from '../service/state-metadata.service';

@Component({
    standalone: true,
    selector: 'app-about',
    imports: [CommonModule],
    templateUrl: './about.component.html',
    styleUrls: ['./about.component.scss']
})
export class AboutComponent {
    readonly metadata$: Observable<StateUiMetadata>;

    constructor(private readonly stateMetadataService: StateMetadataService) {
        this.metadata$ = this.stateMetadataService.metadata$;
    }

    formatGeneratedDate(value: string): string {
        if (!value) {
            return 'Unavailable';
        }
        const parsed = new Date(value);
        return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
    }
}
