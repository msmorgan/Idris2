module Control.Monad.Either

-------------------------------------------------
-- The monad transformer `EitherT e m a` equips a monad with the ability to
-- return a choice of two values.

-- Sequenced actions of `Either e m a` produce a value `a` only if none of the
-- actions in the sequence returned `e`. Because returning `e` exits the
-- computation early, this can be seen as equipping a monad with the ability to
-- throw an exception.

-- This is more powerful than MaybeT which instead equips a monad with the
-- ability to not return a result.
-------------------------------------------------

import Control.Monad.Trans
import Control.Monad.Reader
import Control.Monad.State

public export
data EitherT : (e : Type) -> (m : Type -> Type) -> (a : Type) -> Type where
  MkEitherT : (1 _ : m (Either e a)) -> EitherT e m a

export
%inline
runEitherT : EitherT e m a -> m (Either e a)
runEitherT (MkEitherT x) = x

export
eitherT : Monad m => (a -> m c) -> (b -> m c) -> EitherT a m b -> m c
eitherT f g x = runEitherT x >>= either f g

||| map the underlying computation
||| The basic 'unwrap, apply, rewrap' of this transformer.
export
%inline
mapEitherT : (m (Either e a) -> n (Either e' a')) -> EitherT e m a -> EitherT e' n a'
mapEitherT f = MkEitherT . f . runEitherT

export
bimapEitherT : Functor m => (a -> c) -> (b -> d)
            -> EitherT a m b -> EitherT c m d
bimapEitherT f g x = mapEitherT (map (either (Left . f) (Right . g))) x

||| Analogous to Left, aka throwE
export
%inline
left : Applicative m => e -> EitherT e m a
left = MkEitherT . pure . Left

||| Analogous to Right, aka pure for EitherT
export
%inline
right : Applicative m => a -> EitherT e m a
right = MkEitherT . pure . Right

export
swapEitherT : Functor m => EitherT e m a -> EitherT a m e
swapEitherT = mapEitherT (map (either Right Left))

-------------------------------------------------
-- Methods of the 'exception' theme
-------------------------------------------------

||| aka `left`
export
%inline
throwE : Applicative m => e -> EitherT e m a
throwE = MkEitherT . pure . Left

export
catchE : Monad m => EitherT e m a -> (e -> EitherT e' m a) -> EitherT e' m a
catchE et f
  = MkEitherT $ runEitherT et >>= either (runEitherT . f) (pure . Right)


-------------------------------------------------
-- Interface Implementations
-------------------------------------------------

on : (b -> b -> c) -> (a -> b) -> a -> a -> c
on f g x y = g x `f` g y

public export
Eq (m (Either e a)) => Eq (EitherT e m a) where
 (==) = (==) `on` runEitherT

public export
Ord (m (Either e a)) => Ord (EitherT e m a) where
 compare = compare `on` runEitherT

public export
Show (m (Either e a)) => Show (EitherT e m a) where
  showPrec d (MkEitherT x) = showCon d "MkEitherT" $ showArg x

-- I'm not actually confident about having this instance but it is a sane
-- default and since idris has named implementations it can be swapped out at
-- the use site.
public export
Monad m => Semigroup (EitherT e m a) where
  MkEitherT x <+> MkEitherT y = MkEitherT $ do
    r@(Right _) <- x
      | Left _ => y
    pure r

public export
Functor m => Functor (EitherT e m) where
  map f e = MkEitherT $ map f <$> runEitherT e

public export
Foldable m => Foldable (EitherT e m) where
  foldr f acc (MkEitherT e)
    = foldr (\x,xs => either (const acc) (`f` xs) x) acc e

public export
Traversable m => Traversable (EitherT e m) where
  traverse f (MkEitherT x)
    = MkEitherT <$> traverse (either (pure . Left) (map Right . f)) x

public export
Applicative m => Applicative (EitherT e m) where
  pure = MkEitherT . pure . Right
  f <*> x = MkEitherT [| runEitherT f <*> runEitherT x |]

public export
Monad m => Monad (EitherT e m) where
  x >>= k = MkEitherT $ runEitherT x >>= either (pure . Left) (runEitherT . k)

||| Alternative instance that collects left results, allowing you to try
||| multiple possibilities and combine failures.
public export
(Monad m, Monoid e) => Alternative (EitherT e m) where
  empty = left neutral
  MkEitherT x <|> MkEitherT y = MkEitherT $ do
    Left l <- x
      | Right r => pure (Right r)
    Left l' <- y
      | Right r => pure (Right r)
    pure (Left (l <+> l'))

public export
MonadTrans (EitherT e) where
  lift = MkEitherT . map Right

public export
HasIO m => HasIO (EitherT e m) where
  liftIO act = MkEitherT $ liftIO (io_bind act (pure . Right))

public export
MonadReader r m => MonadReader r (EitherT e m) where
  ask = lift ask
  local f (MkEitherT x) = MkEitherT (local f x)

public export
MonadState s m => MonadState s (EitherT e m) where
  get = lift get
  put = lift . put
