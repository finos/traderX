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

package morphir.internal.collection

import scala.collection.generic.IsTraversableLike
import scala.language.implicitConversions

package object decorators {
  implicit def iteratorDecorator[A](it: Iterator[A]): IteratorDecorator[A] =
    new IteratorDecorator[A](it)

  implicit def IterableDecorator[Repr](
    coll: Repr
  )(implicit traversable: IsTraversableLike[Repr]) =
    new IterableDecorator(traversable.conversion(coll))
}
