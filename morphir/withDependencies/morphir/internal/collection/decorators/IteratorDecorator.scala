/*
Copyright 2020 Morgan Stanley

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */

package morphir.internal.collection.decorators

/** Enriches Iterator with additional methods. */
class IteratorDecorator[A](val `this`: Iterator[A]) extends AnyVal {

  def foldSomeLeft[B](z: B)(op: (B, A) => Option[B]): B = {
    //scalafix:off
    var result: B = z
    while (`this`.hasNext)
      op(result, `this`.next()) match {
        case Some(v) => result = v
        case None    => return result
      }
    result
    //sclafix:on
  }
}
