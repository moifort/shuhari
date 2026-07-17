import { GraphQLError } from 'graphql'

// A domain sentinel IS the error: it is thrown as the message and its GraphQL
// code is derived mechanically ('no-recipe-found' → NO_RECIPE_FOUND). The
// `never` return type lets the helper sit in match() arms while success arms
// keep the resolver's inferred type.
export const domainError = (sentinel: string): never => {
  throw new GraphQLError(sentinel, {
    extensions: { code: sentinel.toUpperCase().replaceAll('-', '_') },
  })
}
