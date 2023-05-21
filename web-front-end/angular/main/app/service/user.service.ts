import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse, HttpHeaders } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { environment } from 'main/environments/environment';
import { User } from '../model/user.model';

@Injectable({
    providedIn: 'root'
})
export class UserService {
    private baseUrl = environment.peopleUrl;

    private httpOptions = {
        headers: new HttpHeaders({
            'Content-Type': 'application/json'
        })
    };
    constructor(private http: HttpClient) { }

    getUsers(searchText: string): Observable<User[]> {
        return this.http.get<User[]>(`${this.baseUrl}/People/GetMatchingPeople`, {
            headers: this.httpOptions.headers,
            params: { SearchText: searchText, Take: 10 }
        }).pipe(
            catchError((error: HttpErrorResponse) => {
                console.error(error);
                return throwError(() => error);
            })
        );
    }
}
