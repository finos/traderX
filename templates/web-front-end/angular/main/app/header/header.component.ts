import { Component, HostListener, OnInit, Output, EventEmitter } from '@angular/core';
import { Observable } from 'rxjs';
import { StateUiMetadata } from '../model/state-ui-metadata.model';
import { StateMetadataService } from '../service/state-metadata.service';

@Component({
    standalone: false,
  selector: 'app-header',
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss']
})
export class HeaderComponent implements OnInit {

  @Output() switchTheme = new EventEmitter();
  metadata$: Observable<StateUiMetadata>;
  isSystemMenuOpen = false;

  constructor(private readonly stateMetadataService: StateMetadataService) {
    this.metadata$ = this.stateMetadataService.metadata$;
  }

  ngOnInit(): void {
  }

  appTitle(stateId: string): string {
    return `TraderX Sample Trading App (${stateId})`;
  }

  toggleSystemMenu(event: MouseEvent): void {
    event.stopPropagation();
    this.isSystemMenuOpen = !this.isSystemMenuOpen;
  }

  closeSystemMenu(): void {
    this.isSystemMenuOpen = false;
  }

  onSystemMenuInteraction(event: MouseEvent): void {
    event.stopPropagation();
  }

  @HostListener('document:click')
  onDocumentClick(): void {
    this.closeSystemMenu();
  }

  @HostListener('document:keydown.escape')
  onEscapeKey(): void {
    this.closeSystemMenu();
  }

}
