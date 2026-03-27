import { Injectable } from '@angular/core';
import { Account } from '../model/account.model';
import { HttpClient, HttpErrorResponse, HttpHeaders } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, retry } from 'rxjs/operators';
import { environment } from 'main/environments/environment';
import { AccountUser } from '../model/user.model';

@Injectable({
  providedIn: 'root'
})
export class AccountService {
  private baseUrl = environment.accountUrl;

  private httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json'
    })
  };
  constructor(private http: HttpClient) { }

  getAccounts(): Observable<Account[]> {
    return this.http.get<Account[]>(`${this.baseUrl}/account/`, this.httpOptions).pipe(
      retry(2),
      catchError((error: HttpErrorResponse) => {
        console.error(error);
        return throwError(() => error);
      })
    );
  }

  addAccount(account: Partial<Account>) {
    return this.http.post<Partial<Account>>(`${this.baseUrl}/account/`, account, this.httpOptions).pipe(
      catchError((error: HttpErrorResponse) => {
        console.error(error);
        return throwError(() => error);
      })
    );
  }

  addAccountUser(accountUser: AccountUser) {
    return this.http.post<AccountUser>(`${this.baseUrl}/accountuser/`, accountUser, this.httpOptions).pipe(
      catchError((error: HttpErrorResponse) => {
        console.error(error);
        return throwError(() => error);
      })
    );
  }

  getAccountUsers(): Observable<AccountUser[]> {
    return this.http.get<AccountUser[]>(`${this.baseUrl}/accountuser/`, this.httpOptions).pipe(
      catchError((error: HttpErrorResponse) => {
        console.error(error);
        return throwError(() => error);
      })
    );
  }
}
